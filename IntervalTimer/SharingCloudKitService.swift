import Foundation
import CloudKit

/// Handles all CloudKit public database operations for routine sharing
@MainActor
@Observable
final class CloudKitSharingService {
    
    private let container = CKContainer(identifier: "iCloud.TypewriterMunky.IntervalTimer")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    
    static let recordType = "SharedRoutine"
    
    enum SharingError: LocalizedError {
        case notSignedIn
        case invalidRecord
        case alreadyDownloaded(String)
        case encodingFailed
        case recordNotFound
        
        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You must be signed into iCloud to share routines."
            case .invalidRecord:
                return "The shared routine data is invalid."
            case .alreadyDownloaded(let name):
                return "You've already downloaded \"\(name)\"."
            case .encodingFailed:
                return "Failed to encode routine data."
            case .recordNotFound:
                return "This shared routine is no longer available."
            }
        }
    }
    
    // MARK: - Publish
    
    /// Publishes a routine to the CloudKit public database.
    /// Returns the CKRecord.ID.recordName for link generation.
    func publishRoutine(_ template: WorkoutTemplate, creatorName: String) async throws -> String {
        // Verify iCloud sign-in before attempting CloudKit operations
        let status = try await container.accountStatus()
        guard status == .available else {
            throw SharingError.notSignedIn
        }
        
        let payload = RoutineSerializer.serialize(template: template, creatorName: creatorName)
        let data = try RoutineSerializer.encode(payload: payload)
        
        // Write JSON to app support directory for CKAsset
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        let tempURL = appSupportDir.appendingPathComponent("share_\(UUID().uuidString).json")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let record: CKRecord
        if let existingRecordName = template.publishedRecordName {
            // Update existing public record
            let recordID = CKRecord.ID(recordName: existingRecordName)
            record = try await publicDB.record(for: recordID)
        } else {
            // Create new public record
            record = CKRecord(recordType: Self.recordType)
        }
        
        record["routineData"] = CKAsset(fileURL: tempURL)
        record["routineName"] = payload.name
        record["originalTemplateID"] = payload.originalTemplateID.uuidString
        record["creatorName"] = payload.creatorName
        record["updatedAt"] = payload.updatedAt as NSDate
        
        let savedRecord = try await publicDB.save(record)
        
        // Update local template with publish info
        template.isPublished = true
        template.publishedRecordName = savedRecord.recordID.recordName
        if template.originalTemplateID == nil {
            template.originalTemplateID = template.id
        }
        
        return savedRecord.recordID.recordName
    }
    
    // MARK: - Fetch
    
    /// Fetches a shared routine payload from the public database by record name.
    func fetchRoutine(recordName: String) async throws -> (SharedRoutinePayload, String) {
        let recordID = CKRecord.ID(recordName: recordName)
        
        let record: CKRecord
        do {
            record = try await publicDB.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            throw SharingError.recordNotFound
        }
        
        guard let asset = record["routineData"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw SharingError.invalidRecord
        }
        
        let data = try Data(contentsOf: fileURL)
        let payload = try RoutineSerializer.decode(data: data)
        
        return (payload, recordName)
    }
    
    // MARK: - Unpublish
    
    /// Removes a routine from the public database.
    func unpublishRoutine(_ template: WorkoutTemplate) async throws {
        guard let recordName = template.publishedRecordName else { return }
        
        let recordID = CKRecord.ID(recordName: recordName)
        try await publicDB.deleteRecord(withID: recordID)
        
        template.isPublished = false
        template.publishedRecordName = nil
    }
    
    // MARK: - Check for Updates
    
    /// Checks if a downloaded routine's source has been updated.
    /// Returns the remote updatedAt date if newer, nil if up-to-date or unavailable.
    func checkForUpdate(sourceRecordName: String, localUpdatedAt: Date?) async -> Date? {
        let recordID = CKRecord.ID(recordName: sourceRecordName)
        
        do {
            let record = try await publicDB.record(for: recordID)
            guard let remoteUpdatedAt = record["updatedAt"] as? Date else { return nil }
            
            if let localDate = localUpdatedAt, remoteUpdatedAt > localDate {
                return remoteUpdatedAt
            }
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - Link Generation
    
    /// Generates a shareable URL for a published routine.
    static func shareURL(for recordName: String) -> URL? {
        URL(string: "intervaltimer://routine/\(recordName)")
    }
    
    /// Parses a record name from an intervaltimer:// URL.
    static func parseShareURL(_ url: URL) -> String? {
        guard url.scheme == "intervaltimer",
              url.host == "routine" else { return nil }
        let recordName = url.pathComponents.dropFirst().first
        return recordName
    }
}
