#!/usr/bin/env swift

import Foundation
import AVFoundation
import AppKit
import CoreVideo

struct Manifest: Decodable {
    struct Segment: Decodable {
        let hook: String
        let body: String
        let accentHex: String
    }

    let width: Int
    let height: Int
    let fps: Int
    let subtitle: String
    let footer: String
    let backgroundImage: String
    let segments: [Segment]
}

enum RenderError: Error {
    case invalidArguments
    case cannotLoadBackground
    case cannotCreateWriter
    case cannotCreateInput
    case cannotCreateAdaptor
    case cannotCreateImage
    case cannotCreateExportSession
    case missingVideoTrack
}

func color(hex: String) -> NSColor {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let r = CGFloat((int >> 16) & 0xff) / 255.0
    let g = CGFloat((int >> 8) & 0xff) / 255.0
    let b = CGFloat(int & 0xff) / 255.0
    return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
}

func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    return min(max(value, minValue), maxValue)
}

func easeOutCubic(_ t: Double) -> Double {
    let p = 1.0 - clamp(t, 0.0, 1.0)
    return 1.0 - p * p * p
}

func loadManifest(path: String) throws -> Manifest {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(Manifest.self, from: data)
}

func audioDuration(url: URL) -> Double {
    let asset = AVURLAsset(url: url)
    let duration = CMTimeGetSeconds(asset.duration)
    if duration.isFinite, duration > 0 { return duration }
    return 34.0
}

func paragraphStyle(alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineSpacing = lineSpacing
    style.lineBreakMode = .byWordWrapping
    return style
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle(alignment: alignment, lineSpacing: lineSpacing)
    ]
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
}

func drawBackground(_ bg: NSImage, canvas: NSSize, t: Double) {
    let bgSize = bg.size
    let baseScale = max(canvas.width / bgSize.width, canvas.height / bgSize.height)
    let zoom = 1.045 + CGFloat(0.045 * t)
    let drawW = bgSize.width * baseScale * zoom
    let drawH = bgSize.height * baseScale * zoom
    let panX = CGFloat(sin(t * Double.pi * 2.0) * 24.0)
    let panY = CGFloat(cos(t * Double.pi * 1.4) * 20.0)
    let rect = NSRect(
        x: (canvas.width - drawW) / 2.0 + panX,
        y: (canvas.height - drawH) / 2.0 + panY,
        width: drawW,
        height: drawH
    )
    bg.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)

    // Cinematic vignette and caption readability.
    NSColor.black.withAlphaComponent(0.22).setFill()
    NSRect(origin: .zero, size: canvas).fill()
    NSGradient(
        starting: NSColor.black.withAlphaComponent(0.78),
        ending: NSColor.black.withAlphaComponent(0.05)
    )?.draw(in: NSRect(x: 0, y: canvas.height * 0.52, width: canvas.width, height: canvas.height * 0.48), angle: 90)
    NSGradient(
        starting: NSColor.black.withAlphaComponent(0.68),
        ending: NSColor.black.withAlphaComponent(0.0)
    )?.draw(in: NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height * 0.35), angle: -90)
}

func frameImage(
    manifest: Manifest,
    bg: NSImage,
    frameIndex: Int,
    totalFrames: Int,
    segmentIndex: Int,
    segmentProgress: Double
) -> CGImage? {
    let size = NSSize(width: manifest.width, height: manifest.height)
    let image = NSImage(size: size)
    image.lockFocus()

    let globalT = Double(frameIndex) / Double(max(totalFrames - 1, 1))
    drawBackground(bg, canvas: size, t: globalT)

    let segment = manifest.segments[segmentIndex]
    let accent = color(hex: segment.accentHex)
    let appear = CGFloat(easeOutCubic(min(segmentProgress / 0.32, 1.0)))
    let floatY = CGFloat((1.0 - appear) * -34.0)

    // Brand chip.
    let chipRect = NSRect(x: 72, y: CGFloat(manifest.height) - 172, width: 430, height: 58)
    drawRoundedRect(chipRect, radius: 29, color: NSColor.black.withAlphaComponent(0.38))
    drawText(
        manifest.subtitle,
        in: NSRect(x: chipRect.minX + 28, y: chipRect.minY + 13, width: chipRect.width - 56, height: 34),
        font: .systemFont(ofSize: 28, weight: .semibold),
        color: accent
    )

    // Main hook.
    drawText(
        segment.hook,
        in: NSRect(x: 72, y: CGFloat(manifest.height) - 485 + floatY, width: CGFloat(manifest.width) - 144, height: 270),
        font: .systemFont(ofSize: 82, weight: .heavy),
        color: NSColor.white.withAlphaComponent(appear),
        lineSpacing: 10
    )

    // Warm glass explanation card.
    let cardRect = NSRect(x: 62, y: 180, width: CGFloat(manifest.width) - 124, height: 320)
    drawRoundedRect(cardRect, radius: 42, color: NSColor.black.withAlphaComponent(0.56))
    accent.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: NSRect(x: cardRect.minX, y: cardRect.maxY - 12, width: cardRect.width * CGFloat(0.22 + 0.76 * globalT), height: 12), xRadius: 6, yRadius: 6).fill()

    drawText(
        segment.body,
        in: NSRect(x: cardRect.minX + 44, y: cardRect.minY + 92, width: cardRect.width - 88, height: 166),
        font: .systemFont(ofSize: 44, weight: .bold),
        color: NSColor.white.withAlphaComponent(0.96),
        lineSpacing: 7
    )

    drawText(
        manifest.footer,
        in: NSRect(x: cardRect.minX + 44, y: cardRect.minY + 34, width: cardRect.width - 88, height: 42),
        font: .systemFont(ofSize: 25, weight: .medium),
        color: NSColor.white.withAlphaComponent(0.68)
    )

    // Small ambient motion dots.
    for i in 0..<4 {
        let phase = globalT * 2.0 * Double.pi + Double(i) * 0.9
        let x = CGFloat(84 + i * 210) + CGFloat(sin(phase) * 9.0)
        let y = CGFloat(590 + i * 42) + CGFloat(cos(phase * 1.2) * 8.0)
        accent.withAlphaComponent(0.10 + CGFloat(i) * 0.018).setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 92, height: 92)).fill()
    }

    // Segment indicator.
    for i in 0..<manifest.segments.count {
        let isActive = i <= segmentIndex
        let w: CGFloat = i == segmentIndex ? 78 : 34
        let x = CGFloat(manifest.width) - 72 - CGFloat(manifest.segments.count - i) * 50 - (i == segmentIndex ? 44 : 0)
        drawRoundedRect(
            NSRect(x: x, y: CGFloat(manifest.height) - 158, width: w, height: 10),
            radius: 5,
            color: isActive ? accent.withAlphaComponent(0.90) : NSColor.white.withAlphaComponent(0.24)
        )
    }

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
    let duration = audioDuration(url: audioURL) + 0.8
    let totalFrames = Int(ceil(duration * Double(manifest.fps)))
    let size = CGSize(width: manifest.width, height: manifest.height)

    guard let bg = NSImage(contentsOfFile: manifest.backgroundImage) else {
        throw RenderError.cannotLoadBackground
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

    let framesPerSegment = max(1, totalFrames / max(manifest.segments.count, 1))

    for frameIndex in 0..<totalFrames {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }

        let segmentIndex = min(manifest.segments.count - 1, frameIndex / framesPerSegment)
        let localFrameStart = segmentIndex * framesPerSegment
        let segmentProgress = Double(frameIndex - localFrameStart) / Double(framesPerSegment)

        guard let cgImage = frameImage(
            manifest: manifest,
            bg: bg,
            frameIndex: frameIndex,
            totalFrames: totalFrames,
            segmentIndex: segmentIndex,
            segmentProgress: segmentProgress
        ), let pool = adaptor.pixelBufferPool,
           let buffer = makePixelBuffer(from: cgImage, size: size, pool: pool) else {
            throw RenderError.cannotCreateImage
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
    let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try videoCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
    videoCompositionTrack?.preferredTransform = videoTrack.preferredTransform

    if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
        let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try audioCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: min(audioAsset.duration, duration)), of: audioTrack, at: .zero)
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

    if let error = export.error {
        throw error
    }
}

let args = CommandLine.arguments
guard args.count == 4 else {
    fputs("Usage: render_image_story_short.swift <manifest.json> <audio.aiff> <output.mp4>\n", stderr)
    throw RenderError.invalidArguments
}

let manifest = try loadManifest(path: args[1])
let audioURL = URL(fileURLWithPath: args[2])
let outputURL = URL(fileURLWithPath: args[3])
let tempVideoURL = outputURL.deletingPathExtension().appendingPathExtension("silent.mov")

try writeSilentVideo(manifest: manifest, audioURL: audioURL, tempVideoURL: tempVideoURL)
try mux(videoURL: tempVideoURL, audioURL: audioURL, outputURL: outputURL)
try? FileManager.default.removeItem(at: tempVideoURL)

