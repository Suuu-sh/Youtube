import Foundation
import AVFoundation
import AppKit
import CoreVideo

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let imageURL = cwd.appendingPathComponent("assets/milk_carton_character.png")
let outURL = cwd.appendingPathComponent("output/mononohonne_realistic_10s_no_voice.mp4")
try? FileManager.default.removeItem(at: outURL)

guard let image = NSImage(contentsOf: imageURL) else { fatalError("Image not found: \(imageURL.path)") }
let width = 1080
let height = 1920
let fps: Int32 = 30
let seconds = 10
let frameCount = Int(fps) * seconds

let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 8_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func drawOutlinedText(_ text: String, rect: CGRect, size: CGFloat, fill: NSColor = .white, stroke: NSColor = .black, strokeWidth: CGFloat = -6, align: NSTextAlignment = .center) {
    let style = NSMutableParagraphStyle(); style.alignment = align; style.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: .heavy),
        .foregroundColor: fill,
        .strokeColor: stroke,
        .strokeWidth: strokeWidth,
        .paragraphStyle: style
    ]
    NSString(string: text).draw(in: rect, withAttributes: attrs)
}
func roundRect(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func blinkAmount(_ t: CGFloat) -> CGFloat {
    let centers: [CGFloat] = [1.3, 3.9, 6.4, 8.2]
    var v: CGFloat = 0
    for c in centers {
        let d = abs(t - c)
        if d < 0.10 { v = max(v, 1 - d / 0.10) }
    }
    return v
}

func makeFrame(_ i: Int) -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    guard let px = buffer else { return nil }
    CVPixelBufferLockBaseAddress(px, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(px), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(px), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = nsctx

    let t = CGFloat(i) / CGFloat(fps)
    let progress = t / CGFloat(seconds)
    let baseScale = max(CGFloat(width) / image.size.width, CGFloat(height) / image.size.height)
    let kenBurns = 1.015 + 0.045 * progress
    let breathe = 1.0 + 0.006 * sin(t * 2.2)
    let scale = baseScale * kenBurns * breathe
    let drawW = image.size.width * scale
    let drawH = image.size.height * scale
    let panX = CGFloat(width) / 2 - drawW / 2 + 10 * sin(t * 0.55)
    let panY = CGFloat(height) / 2 - drawH / 2 - 34 * progress + 6 * sin(t * 0.8)

    NSColor.black.setFill(); NSBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: height)).fill()
    image.draw(in: CGRect(x: panX, y: panY, width: drawW, height: drawH), from: .zero, operation: .sourceOver, fraction: 1.0)

    // subtle handheld vignette
    let vignette = NSGradient(colors: [NSColor(calibratedWhite: 0, alpha: 0.0), NSColor(calibratedWhite: 0, alpha: 0.32)])!
    vignette.draw(in: CGRect(x: -120, y: -80, width: width + 240, height: height + 160), relativeCenterPosition: NSPoint(x: 0, y: 0))

    // Approximate blink overlay on the generated eyes. This is intentionally subtle; Hailuo/Sora should do real motion.
    let b = blinkAmount(t)
    if b > 0.02 {
        let skin = NSColor(calibratedRed: 0.76, green: 0.62, blue: 0.43, alpha: 0.82 * b)
        let eyeRects = [CGRect(x: 347, y: 1002, width: 140, height: 110), CGRect(x: 600, y: 1002, width: 140, height: 110)]
        for r in eyeRects {
            roundRect(CGRect(x: r.minX, y: r.midY - 50*b, width: r.width, height: 100*b), radius: 45, color: skin)
        }
    }

    // Subtitle blocks
    let hook: String
    let sub: String
    if t < 2.5 { hook = "捨てる前に聞け"; sub = "俺、牛乳パック。まだ働ける。" }
    else if t < 5.0 { hook = "実はまな板代わり"; sub = "肉や魚を切る時、広げて下に敷け。" }
    else if t < 7.5 { hook = "洗い物も減る"; sub = "使い終わったら、そのまま処分できる。" }
    else { hook = "即ゴミ箱はやめろ"; sub = "次からは、もう一仕事させてくれ。" }
    drawOutlinedText(hook, rect: CGRect(x: 60, y: 1622, width: 960, height: 145), size: 70)
    roundRect(CGRect(x: 45, y: 125, width: 990, height: 225), radius: 42, color: NSColor(calibratedWhite: 0, alpha: 0.52))
    drawOutlinedText(sub, rect: CGRect(x: 90, y: 165, width: 900, height: 150), size: 50)

    NSGraphicsContext.restoreGraphicsState()
    CVPixelBufferUnlockBaseAddress(px, [])
    return px
}

for i in 0..<frameCount {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    if let frame = makeFrame(i) {
        adaptor.append(frame, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
    }
}
input.markAsFinished()
let sema = DispatchSemaphore(value: 0)
writer.finishWriting { sema.signal() }
sema.wait()
if writer.status != .completed {
    fputs("Failed: \(writer.status) \(String(describing: writer.error))\n", stderr)
    exit(1)
}
print(outURL.path)
