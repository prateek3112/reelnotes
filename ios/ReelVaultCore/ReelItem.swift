import Foundation
import SwiftData

@Model
public final class ReelItem {
    @Attribute(.unique) public var id: String
    public var userId: String?
    public var sourcePlatform: String
    public var originalUrl: String
    public var shortcode: String?
    public var creatorUsername: String?
    public var creatorName: String?
    public var title: String?
    public var topic: String?
    public var summary: String?
    public var hook: String?
    public var transcript: String?
    public var cleanedTranscript: String?
    public var tags: [String]
    public var thumbnailUrl: String?
    public var durationSeconds: Int?
    public var statusRaw: String
    public var errorMessage: String?
    public var createdAt: Date
    public var processedAt: Date?
    public var updatedAt: Date

    public var status: ProcessingStatus {
        get { ProcessingStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    public init(
        id: String,
        originalUrl: String,
        sourcePlatform: String = "instagram",
        shortcode: String? = nil,
        title: String? = nil,
        creatorUsername: String? = nil,
        status: ProcessingStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalUrl = originalUrl
        self.sourcePlatform = sourcePlatform
        self.shortcode = shortcode
        self.title = title
        self.creatorUsername = creatorUsername
        self.statusRaw = status.rawValue
        self.tags = []
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    public convenience init(from dto: Reel) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        let created = formatter.date(from: dto.createdAt) ?? fallbackFormatter.date(from: dto.createdAt) ?? Date()
        let processed = dto.processedAt.flatMap { formatter.date(from: $0) ?? fallbackFormatter.date(from: $0) }
        let updated = dto.updatedAt.flatMap { formatter.date(from: $0) ?? fallbackFormatter.date(from: $0) } ?? created

        self.init(
            id: dto.id,
            originalUrl: dto.originalUrl,
            sourcePlatform: dto.sourcePlatform ?? "instagram",
            shortcode: dto.shortcode,
            title: dto.title,
            creatorUsername: dto.creatorUsername,
            status: dto.status,
            createdAt: created
        )
        self.userId = dto.userId
        self.creatorName = dto.creatorName
        self.topic = dto.topic
        self.summary = dto.summary
        self.hook = dto.hook
        self.transcript = dto.transcript
        self.cleanedTranscript = dto.cleanedTranscript
        self.tags = dto.tags ?? []
        self.thumbnailUrl = dto.thumbnailUrl
        self.durationSeconds = dto.durationSeconds
        self.errorMessage = dto.errorMessage
        self.processedAt = processed
        self.updatedAt = updated
    }

    public func update(from dto: Reel) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        self.title = dto.title ?? self.title
        self.topic = dto.topic ?? self.topic
        self.summary = dto.summary ?? self.summary
        self.hook = dto.hook ?? self.hook
        self.transcript = dto.transcript ?? self.transcript
        self.cleanedTranscript = dto.cleanedTranscript ?? self.cleanedTranscript
        self.creatorUsername = dto.creatorUsername ?? self.creatorUsername
        self.creatorName = dto.creatorName ?? self.creatorName
        self.thumbnailUrl = dto.thumbnailUrl ?? self.thumbnailUrl
        self.durationSeconds = dto.durationSeconds ?? self.durationSeconds
        self.statusRaw = dto.status.rawValue
        self.errorMessage = dto.errorMessage
        if let newTags = dto.tags { self.tags = newTags }
        if let proc = dto.processedAt {
            self.processedAt = formatter.date(from: proc) ?? fallbackFormatter.date(from: proc)
        }
        if let upd = dto.updatedAt {
            self.updatedAt = formatter.date(from: upd) ?? fallbackFormatter.date(from: upd) ?? Date()
        }
    }
}
