import AppKit
import Foundation
import ImageIO
import AVFoundation
import CryptoKit

public final class AppArtworkHelper {
    public static let shared = AppArtworkHelper()

    private var cachedCompressedArtwork: NSImage?
    private let memoryCache = NSCache<NSString, NSImage>()
    private let ioQueue = DispatchQueue(label: "com.mooziac.artwork.io", qos: .userInitiated)

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 15 * 1024 * 1024 // 15 MB max
    }

    public static var defaultArtwork: NSImage {
        return shared.getCompressedDefaultArtwork()
    }

    public func getCompressedDefaultArtwork(targetSize: CGFloat = 128) -> NSImage {
        if let cached = cachedCompressedArtwork {
            return cached
        }

        // Try Bundle resources first, then local filesystem paths
        var sourceImage: NSImage?

        if let bundleUrl = Bundle.main.url(forResource: "MOOZIAC", withExtension: "png") {
            sourceImage = NSImage(contentsOf: bundleUrl)
        }
        if sourceImage == nil, let bundleUrl = Bundle.main.url(forResource: "MOOZIAC_transparent", withExtension: "png") {
            sourceImage = NSImage(contentsOf: bundleUrl)
        }
        if sourceImage == nil {
            let possiblePaths = [
                "MOOZIAC.png",
                "Resources/MOOZIAC.png",
                "Resources/MOOZIAC_transparent.png",
                "/Users/harshshirke/local/projects/mp3kal/MOOZIAC.png",
                "/Users/harshshirke/local/projects/mp3kal/Resources/MOOZIAC.png"
            ]
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    sourceImage = NSImage(contentsOfFile: path)
                    if sourceImage != nil { break }
                }
            }
        }

        guard let original = sourceImage else {
            let fallback = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Mooziac") ?? NSImage()
            cachedCompressedArtwork = fallback
            return fallback
        }

        // Downsample & compress efficiently to memory-efficient thumbnail
        if let tiffData = original.tiffRepresentation,
           let source = CGImageSourceCreateWithData(tiffData as CFData, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: targetSize * 2 // 2x Retina resolution
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                let downsampled = NSImage(cgImage: cgImage, size: NSSize(width: targetSize, height: targetSize))
                cachedCompressedArtwork = downsampled
                return downsampled
            }
        }

        cachedCompressedArtwork = original
        return original
    }

    // MARK: - Disk Cache Folder
    public var thumbnailCacheFolderURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = caches.appendingPathComponent("Mooziac/Thumbnails", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    // MARK: - Deterministic Cache Key
    public func cacheKey(for fileURL: URL, dateAdded: Date, targetSize: CGFloat = 128) -> String {
        var effectiveTimestamp = dateAdded.timeIntervalSince1970
        let jpgSidecar = fileURL.deletingPathExtension().appendingPathExtension("jpg")
        let pngSidecar = fileURL.deletingPathExtension().appendingPathExtension("png")
        if let jpgDate = (try? jpgSidecar.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            effectiveTimestamp = max(effectiveTimestamp, jpgDate.timeIntervalSince1970)
        } else if let pngDate = (try? pngSidecar.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            effectiveTimestamp = max(effectiveTimestamp, pngDate.timeIntervalSince1970)
        }
        let rawKey = "\(fileURL.path)_\(effectiveTimestamp)_\(Int(targetSize))"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Approximate Memory Cost for NSCache
    private func approximateMemoryCost(for image: NSImage) -> Int {
        if let rep = image.representations.first {
            let pixelsWide = rep.pixelsWide > 0 ? rep.pixelsWide : Int(image.size.width * 2)
            let pixelsHigh = rep.pixelsHigh > 0 ? rep.pixelsHigh : Int(image.size.height * 2)
            return max(1024, pixelsWide * pixelsHigh * 4)
        }
        let w = Int(image.size.width * 2)
        let h = Int(image.size.height * 2)
        return max(1024, w * h * 4)
    }

    // MARK: - Fast Memory Cache Lookup
    public func getCachedThumbnail(for track: LocalTrack, targetSize: CGFloat = 128) -> NSImage? {
        let key = cacheKey(for: track.fileURL, dateAdded: track.dateAdded, targetSize: targetSize)
        return memoryCache.object(forKey: key as NSString)
    }

    // MARK: - Invalidation / Deletion of Track Artwork Cache
    public func removeCachedThumbnails(for track: LocalTrack) {
        let sizes: [CGFloat] = [64, 128, 256]
        for size in sizes {
            let key = cacheKey(for: track.fileURL, dateAdded: track.dateAdded, targetSize: size)
            memoryCache.removeObject(forKey: key as NSString)
            let diskURL = thumbnailCacheFolderURL.appendingPathComponent("\(key).jpg")
            if FileManager.default.fileExists(atPath: diskURL.path) {
                try? FileManager.default.removeItem(at: diskURL)
            }
        }
    }

    // MARK: - Synchronous Thumbnail Resolver
    public func getThumbnail(for track: LocalTrack, targetSize: CGFloat = 128) -> NSImage? {
        let key = cacheKey(for: track.fileURL, dateAdded: track.dateAdded, targetSize: targetSize)
        
        // 1. Memory Cache
        if let memoryHit = memoryCache.object(forKey: key as NSString) {
            return memoryHit
        }

        // 2. Disk Cache
        let diskURL = thumbnailCacheFolderURL.appendingPathComponent("\(key).jpg")
        if FileManager.default.fileExists(atPath: diskURL.path),
           let diskImage = NSImage(contentsOf: diskURL) {
            memoryCache.setObject(diskImage, forKey: key as NSString, cost: approximateMemoryCost(for: diskImage))
            return diskImage
        }

        // 3. Extract & Downsample
        if let generated = extractAndDownsample(from: track.fileURL, targetSize: targetSize) {
            saveThumbnailToDisk(image: generated, key: key)
            memoryCache.setObject(generated, forKey: key as NSString, cost: approximateMemoryCost(for: generated))
            return generated
        }

        return getCompressedDefaultArtwork(targetSize: targetSize)
    }

    // MARK: - Asynchronous Thumbnail Resolver
    public func loadThumbnail(for track: LocalTrack, targetSize: CGFloat = 128, completion: @escaping (NSImage?) -> Void) {
        let key = cacheKey(for: track.fileURL, dateAdded: track.dateAdded, targetSize: targetSize)

        // 1. Memory Cache Check (Instant Main Thread Response)
        if let memoryHit = memoryCache.object(forKey: key as NSString) {
            completion(memoryHit)
            return
        }

        // 2. Background Asynchronous Disk & Extraction Lookup
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let diskURL = self.thumbnailCacheFolderURL.appendingPathComponent("\(key).jpg")
            if FileManager.default.fileExists(atPath: diskURL.path),
               let diskImage = NSImage(contentsOf: diskURL) {
                self.memoryCache.setObject(diskImage, forKey: key as NSString, cost: self.approximateMemoryCost(for: diskImage))
                DispatchQueue.main.async {
                    completion(diskImage)
                }
                return
            }

            if let generated = self.extractAndDownsample(from: track.fileURL, targetSize: targetSize) {
                self.saveThumbnailToDisk(image: generated, key: key)
                self.memoryCache.setObject(generated, forKey: key as NSString, cost: self.approximateMemoryCost(for: generated))
                DispatchQueue.main.async {
                    completion(generated)
                }
                return
            }

            let fallback = self.getCompressedDefaultArtwork(targetSize: targetSize)
            DispatchQueue.main.async {
                completion(fallback)
            }
        }
    }

    // MARK: - Downsampling via ImageIO
    public func downsample(data: Data, targetSize: CGFloat = 128) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return createThumbnail(from: source, targetSize: targetSize)
    }

    public func downsample(fileURL: URL, targetSize: CGFloat = 128) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        return createThumbnail(from: source, targetSize: targetSize)
    }

    private func createThumbnail(from source: CGImageSource, targetSize: CGFloat) -> NSImage? {
        let maxPixel = max(16, targetSize * 2) // 2x Retina resolution
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: targetSize, height: targetSize))
    }

    // MARK: - Extraction & Downsampling Pipeline (Tier 1: Embedded -> Tier 2: Sidecar)
    private func extractAndDownsample(from fileURL: URL, targetSize: CGFloat) -> NSImage? {
        // Tier 1: Embedded Audio Tag Metadata (AVFoundation)
        let asset = AVURLAsset(url: fileURL)
        for item in asset.metadata {
            if item.commonKey == .commonKeyArtwork ||
               (item.keySpace == .iTunes && (item.key as? String) == "covr") ||
               (item.keySpace == .id3 && (item.key as? String) == "APIC") ||
               (item.keySpace == .quickTimeMetadata && (item.key as? String)?.contains("artwork") == true) {
                if let data = item.dataValue ?? (item.value as? Data) {
                    if let thumb = downsample(data: data, targetSize: targetSize) {
                        return thumb
                    }
                }
            }
        }
        for item in asset.commonMetadata {
            if item.commonKey == .commonKeyArtwork, let data = item.dataValue ?? (item.value as? Data) {
                if let thumb = downsample(data: data, targetSize: targetSize) {
                    return thumb
                }
            }
        }

        // Tier 2: Sidecar Image Files (.jpg, .png, .jpeg, .webp)
        let jpgSidecar = fileURL.deletingPathExtension().appendingPathExtension("jpg")
        let pngSidecar = fileURL.deletingPathExtension().appendingPathExtension("png")
        let jpegSidecar = fileURL.deletingPathExtension().appendingPathExtension("jpeg")
        let webpSidecar = fileURL.deletingPathExtension().appendingPathExtension("webp")
        
        for sidecar in [jpgSidecar, pngSidecar, jpegSidecar, webpSidecar] {
            if FileManager.default.fileExists(atPath: sidecar.path) {
                if let thumb = downsample(fileURL: sidecar, targetSize: targetSize) {
                    return thumb
                }
            }
        }

        return nil
    }

    // MARK: - Disk Persistence
    private func saveThumbnailToDisk(image: NSImage, key: String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return
        }
        let diskURL = thumbnailCacheFolderURL.appendingPathComponent("\(key).jpg")
        try? jpegData.write(to: diskURL, options: .atomic)
    }
}
