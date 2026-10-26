import AppKit
import SwiftUI

@MainActor
public final class FaviconService: ObservableObject {
    public static let shared = FaviconService()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let cacheDir: URL?

    @Published public private(set) var updateCounter: Int = 0

    private init() {
        if let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let dir = base.appendingPathComponent("com.phonebar.app/Favicons", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.cacheDir = dir
        } else {
            self.cacheDir = nil
        }
    }

    public func cachedFavicon(for host: String) -> NSImage? {
        let key = NSString(string: host.lowercased())
        if let mem = memoryCache.object(forKey: key) {
            return mem
        }
        if let dir = cacheDir {
            let fileURL = dir.appendingPathComponent("\(host.lowercased()).png")
            if let data = try? Data(contentsOf: fileURL), let diskImg = NSImage(data: data) {
                memoryCache.setObject(diskImg, forKey: key)
                return diskImg
            }
        }
        return nil
    }

    public func loadFavicon(for config: WebAppConfig, completion: ((NSImage?) -> Void)? = nil) {
        guard let url = config.url, let host = url.host?.lowercased(), !host.isEmpty else {
            completion?(nil)
            return
        }

        if let cached = cachedFavicon(for: host) {
            completion?(cached)
            return
        }

        Task {
            let image = await fetchFavicon(for: host)
            if let image = image {
                let key = NSString(string: host)
                self.memoryCache.setObject(image, forKey: key)
                if let dir = self.cacheDir {
                    let fileURL = dir.appendingPathComponent("\(host).png")
                    if let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: fileURL)
                    }
                }
                self.updateCounter += 1
            }
            completion?(image)
        }
    }

    private func fetchFavicon(for host: String) async -> NSImage? {
        let endpoints = [
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",
            "https://icons.duckduckgo.com/ip3/\(host).ico"
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 6.0
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let image = NSImage(data: data), image.isValid {
                    return image
                }
            } catch {
                continue
            }
        }
        return nil
    }

    public func menuBarIcon(for image: NSImage) -> NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        let result = NSImage(size: targetSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(origin: .zero, size: targetSize)
        let clipPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        clipPath.addClip()
        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

    private var colorCache: [String: Color] = [:]

    public func dominantColor(for host: String) -> Color {
        let key = host.lowercased()
        if let cached = colorCache[key] {
            return cached
        }
        if let img = cachedFavicon(for: key) {
            let extracted = extractDominantColor(from: img, fallbackHost: key)
            colorCache[key] = extracted
            return extracted
        }
        let fallback = brandColor(for: key)
        colorCache[key] = fallback
        return fallback
    }

    private func extractDominantColor(from image: NSImage, fallbackHost: String) -> Color {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return brandColor(for: fallbackHost)
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0 && height > 0 else { return brandColor(for: fallbackHost) }

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0

        let stepX = max(1, width / 8)
        let stepY = max(1, height / 8)

        for x in stride(from: 0, to: width, by: stepX) {
            for y in stride(from: 0, to: height, by: stepY) {
                if let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                    let r = pixel.redComponent
                    let g = pixel.greenComponent
                    let b = pixel.blueComponent
                    let a = pixel.alphaComponent

                    if a > 0.4 {
                        let brightness = (r * 299 + g * 587 + b * 114) / 1000
                        if brightness > 0.08 && brightness < 0.94 {
                            totalR += r
                            totalG += g
                            totalB += b
                            count += 1
                        }
                    }
                }
            }
        }

        if count > 0 {
            let avgR = Double(totalR / count)
            let avgG = Double(totalG / count)
            let avgB = Double(totalB / count)
            let nsColor = NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let vibrantS = max(0.65, min(0.95, s * 1.35))
            let vibrantB = max(0.75, min(0.95, b * 1.15))
            return Color(hue: Double(h), saturation: Double(vibrantS), brightness: Double(vibrantB))
        }
        return brandColor(for: fallbackHost)
    }

    public func brandColor(for host: String) -> Color {
        var hash: UInt64 = 5381
        for byte in host.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.78, brightness: 0.88)
    }
}

/// SwiftUI View that renders a website favicon with a smooth fallback.
public struct FaviconView: View {
    let app: WebAppConfig
    let size: CGFloat

    @StateObject private var service = FaviconService.shared
    @State private var image: NSImage?

    public init(app: WebAppConfig, size: CGFloat = 30) {
        self.app = app
        self.size = size
    }

    public var body: some View {
        Group {
            if let img = image ?? service.cachedFavicon(for: app.host) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                    Image(systemName: app.symbolName)
                        .font(.system(size: size * 0.52, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: size, height: size)
            }
        }
        .onAppear {
            service.loadFavicon(for: app) { loaded in
                self.image = loaded
            }
        }
        .onChange(of: app.urlString) { _ in
            service.loadFavicon(for: app) { loaded in
                self.image = loaded
            }
        }
    }
}
