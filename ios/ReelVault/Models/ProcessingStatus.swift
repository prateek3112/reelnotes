import SwiftUI

public enum ProcessingStatus: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case downloading = "downloading"
    case extractingAudio = "extracting_audio"
    case transcribing = "transcribing"
    case analyzing = "analyzing"
    case completed = "completed"
    case failed = "failed"

    public var displayName: String {
        switch self {
        case .pending: return "Queued"
        case .downloading: return "Downloading"
        case .extractAudio, .extractingAudio: return "Extracting Audio"
        case .transcribing: return "Transcribing"
        case .analyzing: return "Analyzing"
        case .completed: return "Ready"
        case .failed: return "Failed"
        }
    }

    public static let extractAudio = ProcessingStatus.extractingAudio

    public var iconName: String {
        switch self {
        case .pending: return "clock"
        case .downloading: return "arrow.down.circle"
        case .extractingAudio: return "waveform"
        case .transcribing: return "waveform.and.mic"
        case .analyzing: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .pending: return .secondary
        case .downloading: return .blue
        case .extractingAudio: return .indigo
        case .transcribing: return .purple
        case .analyzing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }

    public var isProcessing: Bool {
        return self != .completed && self != .failed
    }
}
