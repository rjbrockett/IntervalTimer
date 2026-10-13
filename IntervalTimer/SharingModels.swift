import Foundation

// MARK: - Codable transfer objects for CloudKit public database serialization
// These are separate from the @Model classes to avoid SwiftData serialization complications.

struct SharedRoutinePayload: Codable {
    let formatVersion: Int
    let originalTemplateID: UUID
    let name: String
    let showHeartRateZones: Bool
    let creatorName: String
    let updatedAt: Date
    let blocks: [SharedBlockPayload]
    
    init(formatVersion: Int = 1,
         originalTemplateID: UUID,
         name: String,
         showHeartRateZones: Bool,
         creatorName: String,
         updatedAt: Date = Date(),
         blocks: [SharedBlockPayload]) {
        self.formatVersion = formatVersion
        self.originalTemplateID = originalTemplateID
        self.name = name
        self.showHeartRateZones = showHeartRateZones
        self.creatorName = creatorName
        self.updatedAt = updatedAt
        self.blocks = blocks
    }
}

struct SharedBlockPayload: Codable {
    let name: String?
    let repeatCount: Int
    let sortOrder: Int
    let intervals: [SharedIntervalPayload]
    let childBlocks: [SharedBlockPayload]
}

struct SharedIntervalPayload: Codable {
    let name: String
    let duration: TimeInterval
    let sortOrder: Int
    let trackDistance: Bool
    let distanceGoal: Double?
}
