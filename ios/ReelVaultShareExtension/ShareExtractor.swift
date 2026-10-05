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

            // 1. First Pass: Direct URL Provider using NSURL (NSItemProviderReading)
            for provider in attachments {
                if provider.canLoadObject(ofClass: NSURL.self) {
                    if let rawURL = try? await loadObject(provider: provider, ofClass: NSURL.self) as URL {
                        return URLValidator.sanitizeInstagramURL(rawURL)
                    }
                }
            }

            // 2. Second Pass: Plain text with embedded Instagram URL using NSString (NSItemProviderReading)
            for provider in attachments {
                if provider.canLoadObject(ofClass: NSString.self) {
                    if let nsText = try? await loadObject(provider: provider, ofClass: NSString.self),
                       let extracted = extractURL(fromText: String(nsText)) {
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

            // 4. Fourth Pass: UTType.plainText identifier
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = await loadItemAsString(provider: provider),
                       let extracted = extractURL(fromText: text) {
                        return URLValidator.sanitizeInstagramURL(extracted)
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

    private static func loadItemAsString(provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let str = item as? String {
                    continuation.resume(returning: str)
                } else if let nsStr = item as? NSString {
                    continuation.resume(returning: String(nsStr))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
