import Foundation

/// On-device image storage. Body photos are sensitive — everything stays local
/// in the app's Documents/images directory and is excluded from iCloud backup.
nonisolated enum ImageStore {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableDir = dir
            try? mutableDir.setResourceValues(values)
        }
        return dir
    }

    @discardableResult
    static func save(_ data: Data, name: String? = nil) -> String? {
        let fileName = name ?? "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return fileName
        } catch {
            print("[ImageStore] Failed to save image: \(error.localizedDescription)")
            return nil
        }
    }

    static func loadData(_ name: String) -> Data? {
        let url = directory.appendingPathComponent(name)
        return try? Data(contentsOf: url)
    }

    static func delete(_ name: String) {
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
