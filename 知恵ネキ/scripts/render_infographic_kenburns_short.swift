#!/usr/bin/env swift

import Foundation
import AVFoundation
import AppKit
import CoreVideo

struct Manifest: Decodable {
    struct Caption: Decodable {
        let start: Double
        let end: Double
        let title: String
        let body: String
        let focusX: Double
        let focusY: Double
        let zoom: Double
    }

    let width: Int
    let height: Int
    let fps: Int
    let imagePath: String
    let badge: String
    let footer: String
    let backdropMode: String?
    let captions: [Caption]
}

enum RenderError: Error {
    case invalidArguments
    case cannotLoadImage
    case cannotCreateWriter
    case cannotCreateInput
    case cannotCreateAdaptor
    case cannotCreateFrame
    case cannotCreateExportSession
    case missingVideoTrack
}

func loadManifest(_ path: String) throws -> Manifest {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(Manifest.self, from: data)
}

func audioDuration(_ url: URL) -> Double {
    let asset = AVURLAsset(url: url)
    let seconds = CMTimeGetSeconds(asset.duration)
    if seconds.isFinite, seconds > 0 { return seconds }
    return 36.0
}

func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}

func smoothstep(_ x: Double) -> Double {
    let t = clamp(x, 0, 1)
    return t * t * (3 - 2 * t)
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

func activeCaption(_ captions: [Manifest.Caption], at t: Double) -> (Manifest.Caption, Int) {
    if let index = captions.firstIndex(where: { t >= $0.start && t < $0.end }) {
        return (captions[index], index)
    }
    if let last = captions.last {
        return (last, captions.count - 1)
    }
    fatalError("Manifest requires at least one caption")
}

func camera(_ captions: [Manifest.Caption], at t: Double) -> (x: Double, y: Double, zoom: Double) {
    let (current, index) = activeCaption(captions, at: t)
    let prev = index > 0 ? captions[index - 1] : current
    let transition = smoothstep((t - current.start) / 0.55)
    let drift = sin(t * 0.55) * 0.006
    return (
        x: lerp(prev.focusX, current.focusX, transition) + drift,
        y: lerp(prev.focusY, current.focusY, transition),
        zoom: lerp(prev.zoom, current.zoom, transition) * (1.0 + 0.018 * sin(t * 0.38))
    )
}

func paragraph(_ alignment: NSTextAlignment = .left, _ lineSpacing: CGFloat = 0) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = .byWordWrapping
    style.lineSpacing = lineSpacing
    return style
}

func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment, lineSpacing)
    ]
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
}

func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawImageCover(_ image: NSImage, in canvas: NSSize, alpha: CGFloat = 1.0) {
    let scale = max(canvas.width / image.size.width, canvas.height / image.size.height)
    let w = image.size.width * scale
    let h = image.size.height * scale
    image.draw(in: NSRect(x: (canvas.width - w) / 2, y: (canvas.height - h) / 2, width: w, height: h), from: .zero, operation: .sourceOver, fraction: alpha)
}

func makeFrame(manifest: Manifest, source: NSImage, frameIndex: Int, totalFrames: Int, duration: Double) -> CGImage? {
    let canvas = NSSize(width: manifest.width, height: manifest.height)
    let image = NSImage(size: canvas)
    let second = Double(frameIndex) / Double(manifest.fps)
    let (caption, captionIndex) = activeCaption(manifest.captions, at: second)
    let cam = camera(manifest.captions, at: second)

    image.lockFocus()

    if manifest.backdropMode == "solid" {
        NSGradient(
            starting: NSColor(calibratedRed: 0.88, green: 0.79, blue: 0.66, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.08, alpha: 1.0)
        )?.draw(in: NSRect(origin: .zero, size: canvas), angle: 90)
    } else {
        // Soft full-screen backdrop using the same infographic.
        drawImageCover(source, in: canvas, alpha: 1.0)
        NSColor.black.withAlphaComponent(0.42).setFill()
        NSRect(origin: .zero, size: canvas).fill()
    }

    // Main animated infographic layer.
    let baseScale = CGFloat(manifest.width) / source.size.width
    let scale = baseScale * CGFloat(cam.zoom)
    let sourceFocusX = CGFloat(cam.x) * source.size.width
    let sourceFocusY = (1.0 - CGFloat(cam.y)) * source.size.height
    let screenFocusX = canvas.width * 0.50
    let screenFocusY = canvas.height * 0.57
    let drawRect = NSRect(
        x: screenFocusX - sourceFocusX * scale,
        y: screenFocusY - sourceFocusY * scale,
        width: source.size.width * scale,
        height: source.size.height * scale
    )
    rounded(drawRect.insetBy(dx: -12, dy: -12), radius: 34, fill: NSColor.white.withAlphaComponent(0.10))
    source.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    // Readability gradients.
    NSGradient(
        starting: NSColor.black.withAlphaComponent(0.82),
        ending: NSColor.black.withAlphaComponent(0.04)
    )?.draw(in: NSRect(x: 0, y: canvas.height * 0.62, width: canvas.width, height: canvas.height * 0.38), angle: 90)
    NSGradient(
        starting: NSColor.black.withAlphaComponent(0.78),
        ending: NSColor.black.withAlphaComponent(0.06)
    )?.draw(in: NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height * 0.32), angle: -90)

    // Badge.
    let badgeRect = NSRect(x: 58, y: canvas.height - 170, width: 410, height: 60)
    rounded(badgeRect, radius: 30, fill: NSColor.black.withAlphaComponent(0.58))
    drawText(manifest.badge, in: NSRect(x: badgeRect.minX + 28, y: badgeRect.minY + 13, width: badgeRect.width - 56, height: 36), font: .systemFont(ofSize: 28, weight: .semibold), color: NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.44, alpha: 1.0))

    // Segment progress.
    let globalProgress = CGFloat(clamp(second / max(duration, 0.1), 0, 1))
    rounded(NSRect(x: 58, y: canvas.height - 205, width: canvas.width - 116, height: 8), radius: 4, fill: NSColor.white.withAlphaComponent(0.16))
    rounded(NSRect(x: 58, y: canvas.height - 205, width: (canvas.width - 116) * globalProgress, height: 8), radius: 4, fill: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.36, alpha: 1.0))

    // Lower explanation card.
    let appear = CGFloat(smoothstep((second - caption.start) / 0.42))
    let yOffset = CGFloat((1.0 - appear) * -28.0)
    let card = NSRect(x: 58, y: 108 + yOffset, width: canvas.width - 116, height: 318)
    rounded(card, radius: 44, fill: NSColor.black.withAlphaComponent(0.68))
    rounded(NSRect(x: card.minX, y: card.maxY - 10, width: card.width * 0.25, height: 10), radius: 5, fill: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.36, alpha: 1.0))
    drawText(caption.title, in: NSRect(x: card.minX + 42, y: card.minY + 196, width: card.width - 84, height: 82), font: .systemFont(ofSize: 52, weight: .heavy), color: NSColor.white.withAlphaComponent(appear), lineSpacing: 2)
    drawText(caption.body, in: NSRect(x: card.minX + 42, y: card.minY + 82, width: card.width - 84, height: 108), font: .systemFont(ofSize: 37, weight: .bold), color: NSColor.white.withAlphaComponent(0.94 * appear), lineSpacing: 7)
    drawText(manifest.footer, in: NSRect(x: card.minX + 42, y: card.minY + 30, width: card.width - 84, height: 34), font: .systemFont(ofSize: 24, weight: .medium), color: NSColor.white.withAlphaComponent(0.62))

    // Small scene number.
    drawText(String(format: "%02d/%02d", captionIndex + 1, manifest.captions.count), in: NSRect(x: canvas.width - 178, y: canvas.height - 164, width: 120, height: 42), font: .monospacedDigitSystemFont(ofSize: 28, weight: .bold), color: NSColor.white.withAlphaComponent(0.78), alignment: .right)

    image.unlockFocus()
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func makePixelBuffer(from cgImage: CGImage, size: CGSize, pool: CVPixelBufferPool) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
    guard let buffer = pixelBuffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }

    context.clear(CGRect(origin: .zero, size: size))
    context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    return buffer
}

func writeSilentVideo(manifest: Manifest, audioURL: URL, tempVideoURL: URL) throws {
    let duration = audioDuration(audioURL) + 0.8
    let totalFrames = Int(ceil(duration * Double(manifest.fps)))
    let size = CGSize(width: manifest.width, height: manifest.height)

    guard let source = NSImage(contentsOfFile: manifest.imagePath) else {
        throw RenderError.cannotLoadImage
    }

    try? FileManager.default.removeItem(at: tempVideoURL)
    guard let writer = try? AVAssetWriter(outputURL: tempVideoURL, fileType: .mov) else {
        throw RenderError.cannotCreateWriter
    }

    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: manifest.width,
        AVVideoHeightKey: manifest.height
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false

    let attrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: manifest.width,
        kCVPixelBufferHeightKey as String: manifest.height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]

    guard let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs) as AVAssetWriterInputPixelBufferAdaptor? else {
        throw RenderError.cannotCreateAdaptor
    }
    guard writer.canAdd(input) else { throw RenderError.cannotCreateInput }
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    for frameIndex in 0..<totalFrames {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }
        guard let frame = makeFrame(manifest: manifest, source: source, frameIndex: frameIndex, totalFrames: totalFrames, duration: duration),
              let pool = adaptor.pixelBufferPool,
              let buffer = makePixelBuffer(from: frame, size: size, pool: pool) else {
            throw RenderError.cannotCreateFrame
        }
        let time = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(manifest.fps))
        adaptor.append(buffer, withPresentationTime: time)
    }

    input.markAsFinished()
    let group = DispatchGroup()
    group.enter()
    writer.finishWriting { group.leave() }
    group.wait()
}

func mux(videoURL: URL, audioURL: URL, outputURL: URL) throws {
    try? FileManager.default.removeItem(at: outputURL)
    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: videoURL)
    let audioAsset = AVURLAsset(url: audioURL)

    guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
        throw RenderError.missingVideoTrack
    }
    let duration = videoAsset.duration

    let vTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try vTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
    vTrack?.preferredTransform = videoTrack.preferredTransform

    if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
        let aTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try aTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: min(audioAsset.duration, duration)), of: audioTrack, at: .zero)
    }

    guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw RenderError.cannotCreateExportSession
    }
    export.outputURL = outputURL
    export.outputFileType = .mp4
    export.shouldOptimizeForNetworkUse = true

    let group = DispatchGroup()
    group.enter()
    export.exportAsynchronously { group.leave() }
    group.wait()
    if let error = export.error { throw error }
}

let args = CommandLine.arguments
guard args.count == 4 else {
    fputs("Usage: render_infographic_kenburns_short.swift <manifest.json> <audio.wav|aiff> <output.mp4>\n", stderr)
    throw RenderError.invalidArguments
}

let manifest = try loadManifest(args[1])
let audioURL = URL(fileURLWithPath: args[2])
let outputURL = URL(fileURLWithPath: args[3])
let tempVideoURL = outputURL.deletingPathExtension().appendingPathExtension("silent.mov")

try writeSilentVideo(manifest: manifest, audioURL: audioURL, tempVideoURL: tempVideoURL)
try mux(videoURL: tempVideoURL, audioURL: audioURL, outputURL: outputURL)
try? FileManager.default.removeItem(at: tempVideoURL)
