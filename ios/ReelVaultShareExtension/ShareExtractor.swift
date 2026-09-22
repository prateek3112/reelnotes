import Foundation
import UniformTypeIdentifiers

public enum ShareExtractor {

    /// Asynchronously extracts and cleans a shared Reel URL from NSExtensionContext items
    public static func extractURL(from context: NSExtensionContext?) async -> URL? {
        guard let inputItems = context?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            // 1. First Pass: Direct URL Provider
            for provider in attachments {
                if provider.canLoadObject(ofClass: URL.self) {
                    if let rawURL = try? await loadObject(provider: provider, ofClass: URL.self) {
                        return URLValidator.sanitizeInstagramURL(rawURL)
                    }
                }
            }

            // 2. Second Pass: Plain text with embedded Instagram URL
            for provider in attachments {
                if provider.canLoadObject(ofClass: String.self) {
                    if let text = try? await loadObject(provider: provider, ofClass: String.self),
                       let extracted = extractURL(fromText: text) {
                        return URLValidator.sanitizeInstagramURL(extracted)
                    }
                }
            }

            // 3. Third Pass: Legacy UTType.url identifier
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await loadItemAsURL(provider: provider) {
                        return URLValidator.sanitizeInstagramURL(url)
                    }
                }
            }
        }

        return nil
    }

    private static func loadObject<T: NSItemProviderReading>(provider: NSItemProvider, ofClass aClass: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: aClass) { object, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let value = object as? T {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: URLError(.cannotParseResponse))
                }
            }
        }
    }

    private static func extractURL(fromText text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        if let match = matches?.first, let range = Range(match.range, in: text) {
            let candidate = String(text[range])
            return URL(string: candidate)
        }
        return nil
    }

    private static func loadItemAsURL(provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let nsUrl = item as? NSURL {
                    continuation.resume(returning: nsUrl as URL)
                } else if let str = item as? String, let url = URL(string: str) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
