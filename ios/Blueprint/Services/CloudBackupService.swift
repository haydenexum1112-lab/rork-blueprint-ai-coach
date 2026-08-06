import Foundation
import SwiftUI
import CryptoKit
import Combine

/// Manages opt-in encrypted scan metadata backup to iCloud key-value store.
/// Photos stay on-device only — only analysis metadata (scores, dates, plans) is backed up.
@MainActor
final class CloudBackupService: ObservableObject {
    static let shared = CloudBackupService()

    @Published private(set) var isBackingUp: Bool = false
    @Published private(set) var isRestoring: Bool = false
    @Published private(set) var lastError: String?

    private let storeKey = "blueprint_scan_backup_v1"
    private let encryptionKeyKeychain = "blueprint_cloud_backup_key"

    private init() {}

    // MARK: - iCloud availability

    var isAvailable: Bool {
        NSUbiquitousKeyValueStore.default != nil
    }

    // MARK: - Encryption

    private func getEncryptionKey() -> SymmetricKey {
        if let existing = KeychainHelper.get(encryptionKeyKeychain),
           let keyData = Data(base64Encoded: existing) {
            return SymmetricKey(data: keyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        KeychainHelper.set(encryptionKeyKeychain, value: keyData.base64EncodedString())
        return newKey
    }

    private func encrypt(_ data: Data) throws -> Data {
        let key = getEncryptionKey()
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined ?? data
    }

    private func decrypt(_ data: Data) throws -> Data {
        let key = getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Backup

    func backup(scans: [Scan]) async -> Bool {
        guard isAvailable else {
            lastError = "iCloud is not available on this device."
            return false
        }
        isBackingUp = true
        lastError = nil
        defer { isBackingUp = false }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let plainData = try encoder.encode(scans)
            let encrypted = try encrypt(plainData)
            let base64 = encrypted.base64EncodedString()
            NSUbiquitousKeyValueStore.default.set(base64, forKey: storeKey)
            let synced = NSUbiquitousKeyValueStore.default.synchronize()
            return synced
        } catch {
            lastError = "Backup failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore

    func restore() async -> [Scan]? {
        guard isAvailable else {
            lastError = "iCloud is not available on this device."
            return nil
        }
        isRestoring = true
        lastError = nil
        defer { isRestoring = false }

        guard let base64 = NSUbiquitousKeyValueStore.default.string(forKey: storeKey),
              let encrypted = Data(base64Encoded: base64) else {
            lastError = "No backup found in iCloud."
            return nil
        }

        do {
            let decrypted = try decrypt(encrypted)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let scans = try decoder.decode([Scan].self, from: decrypted)
            return scans
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Delete

    func deleteBackup() {
        NSUbiquitousKeyValueStore.default.removeObject(forKey: storeKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - Check

    var hasBackup: Bool {
        NSUbiquitousKeyValueStore.default.string(forKey: storeKey) != nil
    }
}
