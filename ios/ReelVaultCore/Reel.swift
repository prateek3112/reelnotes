import Foundation

public struct ContentStep: Codable, Hashable, Sendable {
    public let type: String
    public let description: String

    public init(type: String, description: String) {
        self.type = type
        self.description = description
    }
}

public struct Reel: Identifiable, Codable, Sendable {
    public let id: String
    public let userId: String?
    public let sourcePlatform: String?
    public let originalUrl: String
    public let shortcode: String?
    public let creatorUsername: String?
    public let creatorName: String?
    public let title: String?
    public let topic: String?
    public let summary: String?
    public let hook: String?
    public let transcript: String?
    public let cleanedTranscript: String?
    public let contentStructure: [ContentStep]?
    public let tags: [String]?
    public let thumbnailUrl: String?
    public let durationSeconds: Int?
    public let status: ProcessingStatus
    public let errorMessage: String?
    public let createdAt: String
    public let processedAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourcePlatform = "source_platform"
        case originalUrl = "original_url"
        case shortcode
        case creatorUsername = "creator_username"
        case creatorName = "creator_name"
        case title
        case topic
        case summary
        case hook
        case transcript
        case cleanedTranscript = "cleaned_transcript"
        case contentStructure = "content_structure"
        case tags
        case thumbnailUrl = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case status
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case processedAt = "processed_at"
        case updatedAt = "updated_at"
    }
}

public struct ReelListDTO: Codable, Sendable {
    public let data: [Reel]
    public let total: Int
    public let page: Int
    public let limit: Int
}
