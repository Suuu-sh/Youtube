#!/usr/bin/env swift

import Foundation
import AVFoundation
import AppKit
import CoreVideo

struct Manifest: Decodable {
    struct Slide: Decodable {
        let title: String
        let lines: [String]
        let accentHex: String
    }

    let width: Int
    let height: Int
    let fps: Int
    let title: String
    let subtitle: String
    let footer: String
    let slides: [Slide]
}

enum RenderError: Error {
    case invalidArguments
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

func loadManifest(path: String) throws -> Manifest {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Manifest.self, from: data)
}

func audioDuration(url: URL) -> Double {
    let asset = AVURLAsset(url: url)
    let duration = CMTimeGetSeconds(asset.duration)
    if duration.isFinite, duration > 0 { return duration }
    return 20.0
}

func slideImage(
    manifest: Manifest,
    slide: Manifest.Slide,
    slideIndex: Int
) -> CGImage? {
    let size = NSSize(width: manifest.width, height: manifest.height)
    let image = NSImage(size: size)
    image.lockFocus()

    let bg1 = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1.0)
    let bg2 = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0)
    NSGradient(starting: bg1, ending: bg2)?.draw(in: NSRect(origin: .zero, size: size), angle: 90)

    let accent = color(hex: slide.accentHex)
    accent.setFill()
    NSBezierPath(roundedRect: NSRect(x: 80, y: CGFloat(manifest.height) - 250, width: CGFloat(manifest.width) - 160, height: 14), xRadius: 7, yRadius: 7).fill()

    let circleRect = NSRect(x: CGFloat(manifest.width) - 220, y: CGFloat(manifest.height) - 320, width: 120, height: 120)
    accent.withAlphaComponent(0.16).setFill()
    NSBezierPath(ovalIn: circleRect).fill()

    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .left
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 84, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: titleStyle
    ]
    let titleRect = NSRect(x: 86, y: CGFloat(manifest.height) - 520, width: CGFloat(manifest.width) - 180, height: 220)
    NSString(string: slide.title).draw(with: titleRect, options: .usesLineFragmentOrigin, attributes: titleAttrs)

    let bodyStyle = NSMutableParagraphStyle()
    bodyStyle.alignment = .left
    bodyStyle.lineSpacing = 18
    let bodyAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 52, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.93, alpha: 1.0),
        .paragraphStyle: bodyStyle
    ]

    var bulletY = CGFloat(manifest.height) - 760
    for line in slide.lines {
        let bulletRect = NSRect(x: 96, y: bulletY + 22, width: 22, height: 22)
        accent.setFill()
        NSBezierPath(ovalIn: bulletRect).fill()

        let lineRect = NSRect(x: 142, y: bulletY, width: CGFloat(manifest.width) - 220, height: 120)
        NSString(string: line).draw(with: lineRect, options: .usesLineFragmentOrigin, attributes: bodyAttrs)
        bulletY -= 160
    }

    let chipStyle = NSMutableParagraphStyle()
    chipStyle.alignment = .center
    let chipAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
        .foregroundColor: accent,
        .paragraphStyle: chipStyle
    ]
    accent.withAlphaComponent(0.14).setFill()
    let chipRect = NSRect(x: 86, y: 250, width: 300, height: 70)
    NSBezierPath(roundedRect: chipRect, xRadius: 20, yRadius: 20).fill()
    NSString(string: "STEP \(slideIndex + 1)").draw(with: NSRect(x: chipRect.minX, y: chipRect.minY + 14, width: chipRect.width, height: 40), options: .usesLineFragmentOrigin, attributes: chipAttrs)

    let footerStyle = NSMutableParagraphStyle()
    footerStyle.alignment = .left
    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 30, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1.0),
        .paragraphStyle: footerStyle
    ]
    NSString(string: manifest.footer).draw(with: NSRect(x: 86, y: 120, width: CGFloat(manifest.width) - 172, height: 40), options: .usesLineFragmentOrigin, attributes: footerAttrs)

    let brandAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
        .foregroundColor: accent
    ]
    NSString(string: manifest.subtitle).draw(at: NSPoint(x: 86, y: CGFloat(manifest.height) - 180), withAttributes: brandAttrs)

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
    let duration = audioDuration(url: audioURL) + 0.6
    let totalFrames = Int(ceil(duration * Double(manifest.fps)))
    let size = CGSize(width: manifest.width, height: manifest.height)

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

    let weights: [Double] = manifest.slides.count == 5 ? [0.18, 0.20, 0.22, 0.22, 0.18] : Array(repeating: 1.0 / Double(max(manifest.slides.count, 1)), count: manifest.slides.count)
    let normalized = weights.map { $0 / weights.reduce(0, +) }
    var frameBreaks: [Int] = []
    var used = 0
    for (index, weight) in normalized.enumerated() {
        let remaining = totalFrames - used
        let count = index == normalized.count - 1 ? remaining : max(1, Int(round(Double(totalFrames) * weight)))
        used += count
        frameBreaks.append(count)
    }

    var frameIndex = 0
    for (slideIndex, slide) in manifest.slides.enumerated() {
        guard let image = slideImage(manifest: manifest, slide: slide, slideIndex: slideIndex) else {
            throw RenderError.cannotCreateImage
        }
        let framesForSlide = frameBreaks[slideIndex]
        for _ in 0..<framesForSlide {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            guard let pool = adaptor.pixelBufferPool,
                  let buffer = makePixelBuffer(from: image, size: size, pool: pool) else {
                throw RenderError.cannotCreateImage
            }
            let time = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(manifest.fps))
            adaptor.append(buffer, withPresentationTime: time)
            frameIndex += 1
        }
    }

    input.markAsFinished()
    writer.finishWriting {}
    while writer.status == .writing {
        Thread.sleep(forTimeInterval: 0.05)
    }
    if writer.status != .completed {
        throw writer.error ?? RenderError.cannotCreateWriter
    }
}

func merge(videoURL: URL, audioURL: URL, outputURL: URL) throws {
    try? FileManager.default.removeItem(at: outputURL)

    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: videoURL)
    let audioAsset = AVURLAsset(url: audioURL)

    guard
        let videoTrack = videoAsset.tracks(withMediaType: .video).first,
        let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else {
        throw RenderError.missingVideoTrack
    }

    try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: videoTrack, at: .zero)
    compVideo.preferredTransform = videoTrack.preferredTransform

    if let audioTrack = audioAsset.tracks(withMediaType: .audio).first,
       let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        try compAudio.insertTimeRange(CMTimeRange(start: .zero, duration: min(audioAsset.duration, videoAsset.duration)), of: audioTrack, at: .zero)
    }

    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw RenderError.cannotCreateExportSession
    }
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.exportAsynchronously {}
    while exporter.status == .waiting || exporter.status == .exporting {
        Thread.sleep(forTimeInterval: 0.1)
    }
    if exporter.status != .completed {
        throw exporter.error ?? RenderError.cannotCreateExportSession
    }
}

do {
    guard CommandLine.arguments.count == 4 else {
        throw RenderError.invalidArguments
    }

    let manifestPath = CommandLine.arguments[1]
    let audioURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
    let manifest = try loadManifest(path: manifestPath)
    let tempVideoURL = outputURL.deletingPathExtension().appendingPathExtension("mov")

    try writeSilentVideo(manifest: manifest, audioURL: audioURL, tempVideoURL: tempVideoURL)
    try merge(videoURL: tempVideoURL, audioURL: audioURL, outputURL: outputURL)
    try? FileManager.default.removeItem(at: tempVideoURL)

    print("Rendered: \(outputURL.path)")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
