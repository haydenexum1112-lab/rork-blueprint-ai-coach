import Foundation
import SwiftUI

/// Loads sample data for demos: downloads the provided goal and current-physique
/// URLs, creates a sample profile, target, and scan, then runs the AI analysis.
@MainActor
enum SampleDataLoader {
    private static let targetURLs: [URL] = [
        URL(string: "https://r2-pub.rork.com/attachments/r98pr37j511juz7cyxri9.jpeg")!,
        URL(string: "https://r2-pub.rork.com/attachments/4b1sv4tds90zmdkd1puya.jpeg")!,
        URL(string: "https://r2-pub.rork.com/attachments/h1eucwl351h37b4mw7hsa.jpeg")!,
        URL(string: "https://r2-pub.rork.com/attachments/26meg2cwoea6gb1hrl8dy.jpeg")!,
        URL(string: "https://r2-pub.rork.com/attachments/wvt6li3y9nw2h9mftrbv9.jpeg")!,
    ]

    // First three current-physique images are used as the baseline scan frames.
    private static let currentURLs: [URL] = [
        URL(string: "https://r2-pub.rork.com/attachments/3wr1ailixe4obozwsae1i.png")!,
        URL(string: "https://r2-pub.rork.com/attachments/rdajgri4mw2hobi34vf4g.png")!,
        URL(string: "https://r2-pub.rork.com/attachments/qp9b4m757lm184ddo4m3s.png")!,
    ]

    static func hasSampleData(in appState: AppState) -> Bool {
        appState.target != nil && appState.scans.contains { scan in
            scan.frameFileNames.allSatisfy { name in
                currentURLs.contains { url in
                    url.lastPathComponent == name
                }
            }
        }
    }

    static func loadSampleData(into appState: AppState) async throws {
        // 1. Ensure a sample profile exists.
        let profile = appState.profile ?? UserProfile(
            name: "Demo",
            age: 22,
            sex: .male,
            heightCm: 183,
            weightKg: 82,
            usesMetric: false,
            experience: .intermediate,
            daysPerWeek: 5,
            equipment: .fullGym,
            goalTags: [.muscleSize, .definition, .athletic]
        )
        if appState.profile == nil {
            appState.saveProfile(profile)
        }

        // 2. Download and save goal images.
        var targetImages: [TargetImage] = []
        for (index, url) in targetURLs.enumerated() {
            let data = try await download(url: url)
            let resized = ImageResizer.resize(data, maxBytes: 900_000) ?? data
            guard let fileName = ImageStore.save(resized) else { continue }
            let caption: String
            switch index {
            case 0: caption = "Front upper-body development and shoulder width"
            case 1: caption = "Overall conditioning and V-taper"
            case 2: caption = "Back width and arm detail from behind"
            case 3: caption = "Abs and midsection leanness"
            default: caption = "Leg development and full-body proportions"
            }
            targetImages.append(TargetImage(fileName: fileName, caption: caption))
        }
        guard targetImages.count == targetURLs.count else {
            throw SampleLoadError.goalDownloadFailed
        }
        let target = TargetReference(images: targetImages)
        appState.saveTarget(target)

        // 3. Download and save current-physique frames.
        var frameData: [Data] = []
        for url in currentURLs {
            let data = try await download(url: url)
            let resized = ImageResizer.resize(data, maxBytes: 900_000) ?? data
            frameData.append(resized)
        }
        guard frameData.count == currentURLs.count else {
            throw SampleLoadError.scanDownloadFailed
        }

        var frameFileNames: [String] = []
        for frame in frameData {
            guard let name = ImageStore.save(frame) else { continue }
            frameFileNames.append(name)
        }
        guard frameFileNames.count == 3 else {
            throw SampleLoadError.scanSaveFailed
        }

        // 4. Build context and run AI analysis.
        let context = buildProfileContext(profile: profile, target: target)
        let targets = targetImages.compactMap { ref -> (Data, String)? in
            guard let data = ImageStore.loadData(ref.fileName) else { return nil }
            return (data, ref.caption)
        }
        let input = AnalysisInput(profileContext: context, frames: frameData, targets: targets)
        let (result, rawJSON) = try await AIService.analyze(input)

        // 5. Save scan, start trial, and mark paywall seen so the full plan is visible in demo.
        let scan = Scan(date: Date(), frameFileNames: frameFileNames, analysis: result, rawJSON: rawJSON)
        appState.addScan(scan)
        appState.startTrial(tier: .everything)
        appState.markPaywallSeen()
        appState.meta.parqPassed = true
        appState.persistMeta()
    }

    private static func download(url: URL) async throws -> Data {
        let request = URLRequest(url: url, timeoutInterval: 60)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw SampleLoadError.network
        }
        return data
    }

    private static func buildProfileContext(profile: UserProfile, target: TargetReference) -> String {
        let goals = profile.goalTags.map { $0.display }.joined(separator: ", ")
        let captions = target.images.map { $0.caption }.joined(separator: " | ")
        return """
        {
          "age": \(profile.age),
          "sex": "\(profile.sex.rawValue)",
          "heightCm": \(Int(profile.heightCm)),
          "weightKg": \(Int(profile.weightKg)),
          "experience": "\(profile.experience.rawValue)",
          "trainingDaysPerWeek": \(profile.daysPerWeek),
          "equipment": "\(profile.equipment.display)",
          "goals": "\(goals)",
          "goalPhotoNotes": "\(captions)"
        }
        """
    }
}

enum SampleLoadError: LocalizedError {
    case goalDownloadFailed
    case scanDownloadFailed
    case scanSaveFailed
    case network

    var errorDescription: String? {
        switch self {
        case .goalDownloadFailed:
            return "Failed to download all goal images. Check your connection and try again."
        case .scanDownloadFailed:
            return "Failed to download all scan frames. Check your connection and try again."
        case .scanSaveFailed:
            return "Failed to save scan frames to the device."
        case .network:
            return "Network error while downloading sample images."
        }
    }
}
