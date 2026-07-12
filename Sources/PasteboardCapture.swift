import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

/// Extracts a non-text payload from `NSPasteboard` when the user copies an
/// image or a file. Returns a normalized representation the store can persist.
///
/// Detection precedence (highest first):
///   1. `public.file-url` — a file reference from Finder / any app that vends one
///   2. `public.png` / `public.tiff` / any image-conforming UTType — a raster image
///
/// Plain text is handled by the existing `ClipboardWatcher.tick()` path.
enum PasteboardCapture {

    // MARK: - Types

    /// A captured non-text payload ready for `HistoryStore` to persist.
    struct Payload {
        enum Kind { case image, file }

        let kind: Kind
        /// Human-readable caption (filename for files, "Image 1920×1080" for images).
        /// This is what goes into `entries.content` so FTS finds the row.
        let caption: String
        /// Raw payload bytes. For images: PNG-encoded. For files: file URL bytes (utf8).
        let bytes: Data
        /// 64×64 PNG thumbnail, or nil if generation failed.
        let thumbnail: Data?
        /// SHA-256 of `bytes` — used for dedupe instead of `content_hash`.
        let payloadHash: String
        /// Image dimensions if kind == .image.
        let width: Int?
        let height: Int?
        /// Total bytes on disk (for files) or PNG-encoded byte count (for images).
        let byteSize: Int
        /// Filename for files; nil for images (unless the pasteboard included one).
        let filename: String?
        /// UTType identifier (e.g. "public.png", "com.adobe.pdf").
        let uti: String?
    }

    // MARK: - Public entry point

    /// Attempts to extract a non-text payload from the pasteboard. Returns nil
    /// if no supported payload is present (caller falls back to text capture).
    static func capture(from pb: NSPasteboard) -> Payload? {
        // File URL takes precedence — a copied file in Finder also puts a TIFF
        // preview on the pasteboard, but we want to treat it as a file.
        if let payload = captureFileURL(from: pb) { return payload }
        if let payload = captureImage(from: pb)   { return payload }
        return nil
    }

    // MARK: - File URL

    private static func captureFileURL(from pb: NSPasteboard) -> Payload? {
        guard let items = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = items.first,
              url.isFileURL
        else { return nil }

        let fm = FileManager.default
        var byteSize = 0
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let sz = attrs[.size] as? Int {
            byteSize = sz
        }
        let filename = url.lastPathComponent
        let uti = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.identifier
        // Store the fileURL bookmark bytes so paste-back can round-trip the URL.
        // Fall back to utf8-encoded absolute path if bookmark generation fails.
        let bytes: Data
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil) {
            bytes = bookmark
        } else {
            bytes = Data(url.absoluteString.utf8)
        }
        let payloadHash = sha256(bytes)
        let thumbnail = thumbnailForFile(at: url)
        let caption = filename
        return Payload(kind: .file,
                       caption: caption,
                       bytes: bytes,
                       thumbnail: thumbnail,
                       payloadHash: payloadHash,
                       width: nil, height: nil,
                       byteSize: byteSize,
                       filename: filename,
                       uti: uti ?? nil)
    }

    // MARK: - Image

    private static func captureImage(from pb: NSPasteboard) -> Payload? {
        // Look for the first pasteboard type that conforms to `public.image`.
        let types = pb.types ?? []
        let imageType = types.first { rawType in
            if let ut = UTType(rawType.rawValue) {
                return ut.conforms(to: .image)
            }
            return rawType == .tiff || rawType == .png
        }
        guard let imageType = imageType,
              let data = pb.data(forType: imageType),
              !data.isEmpty
        else { return nil }

        // Normalize to PNG so downstream code has one format to reason about.
        let png = pngNormalized(data) ?? data
        let (w, h) = imageDimensions(png) ?? (nil, nil)
        let payloadHash = sha256(png)
        let thumb = generateThumbnail(pngData: png, maxDim: 64)
        let dims = (w != nil && h != nil) ? "\(w!)×\(h!)" : "unknown size"
        let caption = "Image \(dims)"
        return Payload(kind: .image,
                       caption: caption,
                       bytes: png,
                       thumbnail: thumb,
                       payloadHash: payloadHash,
                       width: w, height: h,
                       byteSize: png.count,
                       filename: nil,
                       uti: UTType.png.identifier)
    }

    // MARK: - Helpers

    private static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Re-encode arbitrary image bytes (TIFF, PNG, JPEG, HEIC…) as PNG so
    /// persistence and paste-back use a single format.
    private static func pngNormalized(_ data: Data) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg  = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    private static func imageDimensions(_ data: Data) -> (Int, Int)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (w, h)
    }

    /// Generate a `maxDim`-square PNG thumbnail. Uses ImageIO's thumbnail
    /// generator so we don't have to decode the full image into an NSImage.
    static func generateThumbnail(pngData: Data, maxDim: Int) -> Data? {
        guard let src = CGImageSourceCreateWithData(pngData as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim,
            kCGImageSourceShouldCache: false,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, thumb, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// Convert an NSImage (from `NSWorkspace.icon(forFile:)`) into a PNG thumbnail.
    private static func thumbnailForFile(at url: URL) -> Data? {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        guard let tiff = icon.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        return png
    }
}
