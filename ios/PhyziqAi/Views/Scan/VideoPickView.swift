import PhotosUI
import SwiftUI

/// Movie file received from the Photos picker, copied into tmp for reading.
nonisolated struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

/// Pick a 20–30 second slow-turn video; frames are extracted automatically.
struct VideoPickView: View {
    let onComplete: ([Data]) -> Void
    let onBack: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    Haptics.impact(.light)
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 110, height: 110)
                    Image(systemName: isProcessing ? "waveform" : "video.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.pulse, isActive: isProcessing)
                }

                Text(isProcessing ? "Extracting frames…" : "Scan video")
                    .font(.displayFont(28))
                    .foregroundStyle(Theme.textPrimary)

                Text(isProcessing
                    ? "Pulling your front, side, and back angles from the video."
                    : "Record a 20–30 second video turning slowly in place, then pick it here. We'll grab the front, side, and back frames automatically.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            if !isProcessing {
                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    Text("Choose video")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else {
                SwiftUI.ProgressView()
                    .tint(Theme.accent)
                    .padding(.bottom, 40)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            process(newItem)
        }
    }

    private func process(_ item: PhotosPickerItem) {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    throw VideoFrameExtractorError.unreadable
                }
                let frames = try await VideoFrameExtractor.extractFrames(from: movie.url)
                try? FileManager.default.removeItem(at: movie.url)
                Haptics.success()
                onComplete(frames)
            } catch {
                errorMessage = error.localizedDescription
                isProcessing = false
                pickerItem = nil
            }
        }
    }
}
