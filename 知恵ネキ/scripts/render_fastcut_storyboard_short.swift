#!/usr/bin/env swift

import Foundation
import AVFoundation
import AppKit
import CoreVideo

struct Manifest: Decodable {
    struct Scene: Decodable {
        let title: String
        let body: String
        let tag: String
    }

    let width: Int
    let height: Int
    let fps: Int
    let spriteSheet: String?
    let columns: Int?
    let rows: Int?
    let imageFiles: [String]?
    let badge: String
    let footer: String
    let scenes: [Scene]
}

enum RenderError: Error {
    case invalidArguments
    case cannotLoadImage
    case cannotCrop
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

func duration(_ url: URL) -> Double {
    let asset = AVURLAsset(url: url)
    let seconds = CMTimeGetSeconds(asset.duration)
    if seconds.isFinite, seconds > 0 { return seconds }
    return 34.0
}

func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}

func smooth(_ x: Double) -> Double {
    let t = clamp(x, 0, 1)
    return t * t * (3 - 2 * t)
}

func paragraph(_ alignment: NSTextAlignment = .left, _ lineSpacing: CGFloat = 0) -> NSMutableParagraphStyle {
    let p = NSMutableParagraphStyle()
    p.alignment = alignment
    p.lineBreakMode = .byWordWrapping
    p.lineSpacing = lineSpacing
    return p
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

func cropPanels(sheet: NSImage, columns: Int, rows: Int) throws -> [NSImage] {
    guard let cg = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw RenderError.cannotCrop
    }
    let width = cg.width
    let height = cg.height
    let cellW = width / columns
    let cellH = height / rows
    var result: [NSImage] = []
    for r in 0..<rows {
        for c in 0..<columns {
            // CG coordinates start at top-left for cropped images from CGImage.
            let rect = CGRect(x: c * cellW, y: r * cellH, width: cellW, height: cellH)
            guard let cropped = cg.cropping(to: rect) else { throw RenderError.cannotCrop }
            result.append(NSImage(cgImage: cropped, size: NSSize(width: cellW, height: cellH)))
        }
    }
    return result
}

func drawCover(_ image: NSImage, in rect: NSRect, fraction: CGFloat = 1.0, zoom: CGFloat = 1.0, offsetX: CGFloat = 0, offsetY: CGFloat = 0) {
    let scale = max(rect.width / image.size.width, rect.height / image.size.height) * zoom
    let w = image.size.width * scale
    let h = image.size.height * scale
    image.draw(
        in: NSRect(x: rect.midX - w / 2 + offsetX, y: rect.midY - h / 2 + offsetY, width: w, height: h),
        from: .zero,
        operation: .sourceOver,
        fraction: fraction
    )
}

func makeFrame(manifest: Manifest, panels: [NSImage], frame: Int, totalFrames: Int, audioSeconds: Double) -> CGImage? {
    let canvas = NSSize(width: manifest.width, height: manifest.height)
    let frameTime = Double(frame) / Double(manifest.fps)
    let sceneDur = audioSeconds / Double(max(manifest.scenes.count, 1))
    let sceneIndex = min(manifest.scenes.count - 1, max(0, Int(frameTime / sceneDur)))
    let local = (frameTime - Double(sceneIndex) * sceneDur) / sceneDur
    let panel = panels[min(sceneIndex, panels.count - 1)]
    let scene = manifest.scenes[sceneIndex]

    let image = NSImage(size: canvas)
    image.lockFocus()

    // Native vertical background. The old version placed a square crop in the center,
    // which made only the middle look bright. Draw one 9:16 image full-screen instead.
    let zoom = CGFloat(1.005 + 0.025 * smooth(local))
    let panX = CGFloat((Double(sceneIndex % 3) - 1.0) * 18.0 * smooth(local))
    let panY = CGFloat((Double((sceneIndex + 1) % 3) - 1.0) * 14.0 * smooth(local))
    drawCover(panel, in: NSRect(origin: .zero, size: canvas), fraction: 1.0, zoom: zoom, offsetX: panX, offsetY: panY)
    NSColor.black.withAlphaComponent(0.16).setFill()
    NSRect(origin: .zero, size: canvas).fill()

    // Gradients only behind text; no horizontal dark band across the image.
    NSGradient(
        starting: NSColor.black.withAlphaComponent(0.82),
        ending: NSColor.black.withAlphaComponent(0.00)
    )?.draw(in: NSRect(x: 0, y: canvas.height * 0.64, width: canvas.width, height: canvas.height * 0.36), angle: 90)
    NSGradient(
        starting: NSColor.black.withAlphaComponent(0.82),
        ending: NSColor.black.withAlphaComponent(0.00)
    )?.draw(in: NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height * 0.30), angle: -90)

    let gold = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.28, alpha: 1.0)
    rounded(NSRect(x: 54, y: canvas.height - 166, width: 470, height: 62), radius: 31, fill: NSColor.black.withAlphaComponent(0.62))
    drawText(manifest.badge, in: NSRect(x: 86, y: canvas.height - 150, width: 410, height: 34), font: .systemFont(ofSize: 28, weight: .heavy), color: gold)

    let progressW = (canvas.width - 108) * CGFloat(Double(sceneIndex + 1) / Double(manifest.scenes.count))
    rounded(NSRect(x: 54, y: canvas.height - 205, width: canvas.width - 108, height: 9), radius: 4.5, fill: NSColor.white.withAlphaComponent(0.18))
    rounded(NSRect(x: 54, y: canvas.height - 205, width: progressW, height: 9), radius: 4.5, fill: gold)
    drawText(String(format: "%02d/%02d", sceneIndex + 1, manifest.scenes.count), in: NSRect(x: canvas.width - 190, y: canvas.height - 158, width: 136, height: 40), font: .monospacedDigitSystemFont(ofSize: 28, weight: .heavy), color: .white, alignment: .right)

    let titleY = canvas.height - 410
    drawText(scene.tag, in: NSRect(x: 70, y: titleY + 108, width: canvas.width - 140, height: 46), font: .systemFont(ofSize: 34, weight: .bold), color: gold)
    drawText(scene.title, in: NSRect(x: 66, y: titleY, width: canvas.width - 132, height: 112), font: .systemFont(ofSize: 58, weight: .heavy), color: .white, lineSpacing: 4)

    let card = NSRect(x: 54, y: 110, width: canvas.width - 108, height: 222)
    rounded(card, radius: 38, fill: NSColor.black.withAlphaComponent(0.72))
    rounded(NSRect(x: card.minX, y: card.maxY - 9, width: card.width * 0.26, height: 9), radius: 4.5, fill: gold)
    drawText(scene.body, in: NSRect(x: card.minX + 38, y: card.minY + 78, width: card.width - 76, height: 92), font: .systemFont(ofSize: 39, weight: .heavy), color: .white, lineSpacing: 6)
    drawText(manifest.footer, in: NSRect(x: card.minX + 38, y: card.minY + 31, width: card.width - 76, height: 30), font: .systemFont(ofSize: 23, weight: .semibold), color: NSColor.white.withAlphaComponent(0.62))

    image.unlockFocus()
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func makePixelBuffer(from cgImage: CGImage, size: CGSize, pool: CVPixelBufferPool) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
    guard let buffer = pixelBuffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }
    ctx.clear(CGRect(origin: .zero, size: size))
    ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
    return buffer
}

func writeVideo(manifest: Manifest, audioURL: URL, tempVideoURL: URL) throws {
    let audioSeconds = duration(audioURL) + 0.5
    let totalFrames = Int(ceil(audioSeconds * Double(manifest.fps)))
    let size = CGSize(width: manifest.width, height: manifest.height)
    let panels: [NSImage]
    if let imageFiles = manifest.imageFiles, !imageFiles.isEmpty {
        panels = try imageFiles.map { path in
            guard let image = NSImage(contentsOfFile: path) else { throw RenderError.cannotLoadImage }
            return image
        }
    } else {
        guard let spritePath = manifest.spriteSheet,
              let columns = manifest.columns,
              let rows = manifest.rows,
              let sheet = NSImage(contentsOfFile: spritePath) else { throw RenderError.cannotLoadImage }
        panels = try cropPanels(sheet: sheet, columns: columns, rows: rows)
    }

    try? FileManager.default.removeItem(at: tempVideoURL)
    guard let writer = try? AVAssetWriter(outputURL: tempVideoURL, fileType: .mov) else { throw RenderError.cannotCreateWriter }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: manifest.width,
        AVVideoHeightKey: manifest.height
    ])
    input.expectsMediaDataInRealTime = false
    let attrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: manifest.width,
        kCVPixelBufferHeightKey as String: manifest.height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    guard let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs) as AVAssetWriterInputPixelBufferAdaptor? else { throw RenderError.cannotCreateAdaptor }
    guard writer.canAdd(input) else { throw RenderError.cannotCreateInput }
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    for i in 0..<totalFrames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
        guard let cg = makeFrame(manifest: manifest, panels: panels, frame: i, totalFrames: totalFrames, audioSeconds: audioSeconds),
              let pool = adaptor.pixelBufferPool,
              let buffer = makePixelBuffer(from: cg, size: size, pool: pool) else { throw RenderError.cannotCreateFrame }
        adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(manifest.fps)))
    }
    input.markAsFinished()
    let group = DispatchGroup(); group.enter()
    writer.finishWriting { group.leave() }
    group.wait()
}

func mux(videoURL: URL, audioURL: URL, outputURL: URL) throws {
    try? FileManager.default.removeItem(at: outputURL)
    let comp = AVMutableComposition()
    let vAsset = AVURLAsset(url: videoURL)
    let aAsset = AVURLAsset(url: audioURL)
    guard let vTrackSrc = vAsset.tracks(withMediaType: .video).first else { throw RenderError.missingVideoTrack }
    let dur = vAsset.duration
    let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try vTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vTrackSrc, at: .zero)
    vTrack?.preferredTransform = vTrackSrc.preferredTransform
    if let aTrackSrc = aAsset.tracks(withMediaType: .audio).first {
        let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try aTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: min(aAsset.duration, dur)), of: aTrackSrc, at: .zero)
    }
    guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { throw RenderError.cannotCreateExportSession }
    export.outputURL = outputURL
    export.outputFileType = .mp4
    export.shouldOptimizeForNetworkUse = true
    let group = DispatchGroup(); group.enter()
    export.exportAsynchronously { group.leave() }
    group.wait()
    if let error = export.error { throw error }
}

let args = CommandLine.arguments
guard args.count == 4 else {
    fputs("Usage: render_fastcut_storyboard_short.swift <manifest.json> <audio.m4a|mp4> <output.mp4>\n", stderr)
    throw RenderError.invalidArguments
}

let manifest = try loadManifest(args[1])
let audioURL = URL(fileURLWithPath: args[2])
let outputURL = URL(fileURLWithPath: args[3])
let tempURL = outputURL.deletingPathExtension().appendingPathExtension("silent.mov")
try writeVideo(manifest: manifest, audioURL: audioURL, tempVideoURL: tempURL)
try mux(videoURL: tempURL, audioURL: audioURL, outputURL: outputURL)
try? FileManager.default.removeItem(at: tempURL)

