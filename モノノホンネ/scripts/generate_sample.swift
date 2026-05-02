import Foundation
import AVFoundation
import AppKit
import CoreVideo

let width = 1080
let height = 1920
let fps: Int32 = 30
let seconds = 10
let frameCount = Int(fps) * seconds
let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/mononohonne_sample_10s.mp4")
try? FileManager.default.removeItem(at: outURL)

let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 7_000_000,
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

func ease(_ x: CGFloat) -> CGFloat { return 0.5 - cos(x * .pi) / 2 }
func paragraph(_ text: String, fontSize: CGFloat, weight: NSFont.Weight = .bold, color: NSColor = .white, align: NSTextAlignment = .center) -> NSMutableParagraphStyle {
    let p = NSMutableParagraphStyle(); p.alignment = align; p.lineBreakMode = .byWordWrapping; return p
}
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
func strokeRoundRect(_ rect: CGRect, radius: CGFloat, color: NSColor, line: CGFloat) {
    color.setStroke(); let p = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius); p.lineWidth = line; p.stroke()
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
    let wobble = sin(t * 2.5) * 18
    let zoom = 1.0 + 0.018 * sin(t * 0.9)
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(width)/2, y: CGFloat(height)/2)
    ctx.scaleBy(x: zoom, y: zoom)
    ctx.translateBy(x: -CGFloat(width)/2, y: -CGFloat(height)/2)

    // warm kitchen background
    let grad = NSGradient(colors: [NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.52, alpha: 1), NSColor(calibratedRed: 0.43, green: 0.27, blue: 0.16, alpha: 1)])!
    grad.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: 90)
    NSColor(calibratedWhite: 0, alpha: 0.18).setFill(); NSBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: height)).fill()
    // counter
    roundRect(CGRect(x: -80, y: 130, width: 1240, height: 430), radius: 80, color: NSColor(calibratedRed: 0.58, green: 0.38, blue: 0.22, alpha: 1))
    roundRect(CGRect(x: 40, y: 165, width: 1000, height: 310), radius: 44, color: NSColor(calibratedRed: 0.83, green: 0.72, blue: 0.58, alpha: 1))
    // blurred shelves
    for k in 0..<5 { roundRect(CGRect(x: 80 + k*190, y: 1470 + (k%2)*60, width: 120, height: 190), radius: 28, color: NSColor(calibratedWhite: 1, alpha: 0.10)) }

    // cutting board and salmon pieces
    roundRect(CGRect(x: 170, y: 390, width: 740, height: 300), radius: 36, color: NSColor(calibratedRed: 0.92, green: 0.84, blue: 0.70, alpha: 1))
    for k in 0..<3 { roundRect(CGRect(x: 420 + k*90, y: 520 + (k%2)*12, width: 76, height: 44), radius: 18, color: NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.26, alpha: 1)) }

    // anthropomorphic milk carton
    let cx: CGFloat = 540 + wobble
    let baseY: CGFloat = 620 + sin(t * 3.1) * 9
    // shadow
    NSColor(calibratedWhite: 0, alpha: 0.20).setFill(); NSBezierPath(ovalIn: CGRect(x: cx - 250, y: baseY - 70, width: 500, height: 80)).fill()
    // arms behind
    NSColor(calibratedRed: 0.94, green: 0.91, blue: 0.84, alpha: 1).setStroke()
    var leftArm = NSBezierPath(); leftArm.lineWidth = 30; leftArm.lineCapStyle = .round
    leftArm.move(to: CGPoint(x: cx - 185, y: baseY + 470)); leftArm.curve(to: CGPoint(x: cx - 330, y: baseY + 560 + 38*sin(t*4)), controlPoint1: CGPoint(x: cx - 250, y: baseY + 520), controlPoint2: CGPoint(x: cx - 300, y: baseY + 535)); leftArm.stroke()
    var rightArm = NSBezierPath(); rightArm.lineWidth = 30; rightArm.lineCapStyle = .round
    rightArm.move(to: CGPoint(x: cx + 185, y: baseY + 455)); rightArm.curve(to: CGPoint(x: cx + 335, y: baseY + 500 + 55*sin(t*5)), controlPoint1: CGPoint(x: cx + 250, y: baseY + 500), controlPoint2: CGPoint(x: cx + 295, y: baseY + 465)); rightArm.stroke()
    // body
    roundRect(CGRect(x: cx - 190, y: baseY, width: 380, height: 700), radius: 46, color: NSColor(calibratedRed: 0.94, green: 0.91, blue: 0.84, alpha: 1))
    strokeRoundRect(CGRect(x: cx - 190, y: baseY, width: 380, height: 700), radius: 46, color: NSColor(calibratedRed: 0.55, green: 0.49, blue: 0.42, alpha: 1), line: 8)
    // top gable
    let top = NSBezierPath(); top.move(to: CGPoint(x: cx - 190, y: baseY + 700)); top.line(to: CGPoint(x: cx, y: baseY + 850)); top.line(to: CGPoint(x: cx + 190, y: baseY + 700)); top.close(); NSColor(calibratedRed: 0.88, green: 0.84, blue: 0.76, alpha: 1).setFill(); top.fill(); NSColor(calibratedRed: 0.55, green: 0.49, blue: 0.42, alpha: 1).setStroke(); top.lineWidth = 8; top.stroke()
    // label
    roundRect(CGRect(x: cx - 125, y: baseY + 85, width: 250, height: 110), radius: 22, color: NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.86, alpha: 1))
    drawOutlinedText("MILK", rect: CGRect(x: cx - 125, y: baseY + 108, width: 250, height: 70), size: 48, fill: .white, stroke: NSColor(calibratedWhite: 0, alpha: 0.55), strokeWidth: -3)
    // eyes
    for side in [-1, 1] {
        let ex = cx + CGFloat(side) * 75
        NSColor.white.setFill(); NSBezierPath(ovalIn: CGRect(x: ex - 56, y: baseY + 465, width: 112, height: 112)).fill()
        NSColor(calibratedRed: 0.16, green: 0.45, blue: 0.85, alpha: 1).setFill(); NSBezierPath(ovalIn: CGRect(x: ex - 33 + 7*sin(t*2), y: baseY + 487, width: 66, height: 66)).fill()
        NSColor.black.setFill(); NSBezierPath(ovalIn: CGRect(x: ex - 17 + 7*sin(t*2), y: baseY + 505, width: 34, height: 34)).fill()
        NSColor.white.setFill(); NSBezierPath(ovalIn: CGRect(x: ex + 3 + 7*sin(t*2), y: baseY + 530, width: 16, height: 16)).fill()
    }
    // eyebrows
    NSColor.black.setStroke()
    for side in [-1, 1] {
        let p = NSBezierPath(); p.lineWidth = 10; p.lineCapStyle = .round
        let ex = cx + CGFloat(side) * 75
        p.move(to: CGPoint(x: ex - CGFloat(side)*55, y: baseY + 612)); p.line(to: CGPoint(x: ex + CGFloat(side)*35, y: baseY + 585)); p.stroke()
    }
    // mouth animated
    let mouthOpen = abs(sin(t * 8))
    NSColor(calibratedRed: 0.18, green: 0.06, blue: 0.06, alpha: 1).setFill(); NSBezierPath(ovalIn: CGRect(x: cx - 45, y: baseY + 375, width: 90, height: 22 + 58*mouthOpen)).fill()
    // cheeks
    NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.45, alpha: 0.30).setFill(); NSBezierPath(ovalIn: CGRect(x: cx - 145, y: baseY + 405, width: 70, height: 36)).fill(); NSBezierPath(ovalIn: CGRect(x: cx + 75, y: baseY + 405, width: 70, height: 36)).fill()
    ctx.restoreGState()

    // top hook and bottom subtitles
    let hook: String
    let sub: String
    if t < 2.5 { hook = "捨てる前に聞け"; sub = "俺、牛乳パック。まだ働ける。" }
    else if t < 5.0 { hook = "まな板代わりに使える"; sub = "肉や魚を切る時、広げて下に敷け。" }
    else if t < 7.5 { hook = "洗い物も減る"; sub = "使い終わったら、そのまま処分できる。" }
    else { hook = "年間で地味に節約"; sub = "だから次から、即ゴミ箱はやめろ。" }
    drawOutlinedText(hook, rect: CGRect(x: 70, y: 1610, width: 940, height: 150), size: 62)
    roundRect(CGRect(x: 55, y: 145, width: 970, height: 230), radius: 42, color: NSColor(calibratedWhite: 0, alpha: 0.48))
    drawOutlinedText(sub, rect: CGRect(x: 95, y: 180, width: 890, height: 170), size: 48)
    drawOutlinedText("モノノホンネ 試作", rect: CGRect(x: 55, y: 60, width: 970, height: 70), size: 32, fill: NSColor(calibratedWhite: 1, alpha: 0.8), stroke: NSColor(calibratedWhite: 0, alpha: 0.5), strokeWidth: -2)

    NSGraphicsContext.restoreGraphicsState()
    CVPixelBufferUnlockBaseAddress(px, [])
    return px
}

for i in 0..<frameCount {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    if let frame = makeFrame(i) {
        let time = CMTime(value: CMTimeValue(i), timescale: fps)
        adaptor.append(frame, withPresentationTime: time)
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
