import Foundation

public enum URLValidator {
    private static let instagramPatterns = [
        #"instagram\.com/(?:reel|reels)/([A-Za-z0-9_-]+)"#,
        #"instagram\.com/p/([A-Za-z0-9_-]+)"#
    ]

    /// Validates whether a given URL is a supported Instagram Reel or post link.
    public static func isValidInstagramURL(_ url: URL) -> Bool {
        return extractShortcode(from: url) != nil
    }

    /// Extracts the unique Instagram shortcode (e.g. "C8ABC123xyz").
    public static func extractShortcode(from url: URL) -> String? {
        let urlString = url.absoluteString
        for pattern in instagramPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: urlString, options: [], range: NSRange(location: 0, length: urlString.utf16.count)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: urlString) {
                return String(urlString[range])
            }
        }
        return nil
    }

    /// Strips tracking query parameters (`igsh`, `utm_*`, `fbclid`) while preserving the canonical Reel path.
    public static func sanitizeInstagramURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let trackingParams: Set<String> = [
            "igsh", "utm_source", "utm_medium", "utm_campaign", "utm_term",
            "utm_content", "fbclid", "igshid"
        ]

        if let queryItems = components.queryItems {
            let filtered = queryItems.filter { !trackingParams.contains($0.name.lowercased()) }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        // Ensure trailing slash on path
        if let path = components.path as String?, !path.hasSuffix("/") {
            components.path = path + "/"
        }

        return components.url ?? url
    }
}
