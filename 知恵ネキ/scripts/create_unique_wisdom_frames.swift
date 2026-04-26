#!/usr/bin/env swift
import Foundation
import AppKit

struct Video: Decodable { let slug: String; let mood: String; let scenes: [[StringValue]]? }
struct StringValue: Decodable {}
struct BatchVideo: Decodable {
    let slug: String
    let mood: String
    let title: String
    let scenes: [[JSONAny]]
}
struct JSONAny: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let a = try? c.decode([String].self) { value = a }
        else { value = "" }
    }
}

func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: alpha)
}
func rect(_ x: CGFloat,_ y: CGFloat,_ w: CGFloat,_ h: CGFloat) -> NSRect { NSRect(x: x, y: y, width: w, height: h) }
func rounded(_ r: NSRect, _ radius: CGFloat, _ c: NSColor) { c.setFill(); NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill() }
func line(_ from: NSPoint, _ to: NSPoint, _ c: NSColor, _ width: CGFloat) { c.setStroke(); let p=NSBezierPath(); p.lineWidth=width; p.move(to: from); p.line(to: to); p.stroke() }
func ellipse(_ r: NSRect, _ c: NSColor) { c.setFill(); NSBezierPath(ovalIn: r).fill() }
func text(_ s: String, _ r: NSRect, _ size: CGFloat, _ weight: NSFont.Weight, _ c: NSColor, _ align: NSTextAlignment = .center) {
    let p=NSMutableParagraphStyle(); p.alignment=align; p.lineBreakMode = .byWordWrapping
    let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor:c, .paragraphStyle:p]
    NSString(string:s).draw(with:r, options:[.usesLineFragmentOrigin,.usesFontLeading], attributes:attrs)
}
func drawGradient(_ size: NSSize, _ top: NSColor, _ bottom: NSColor) {
    let g=NSGradient(colors:[bottom, top])!; g.draw(in: rect(0,0,size.width,size.height), angle: 90)
}
func drawPerson(cx: CGFloat, base: CGFloat, scale: CGFloat, suit: NSColor, skin: NSColor, accent: NSColor, pose: Int) {
    // Body
    let body = NSBezierPath()
    body.move(to: NSPoint(x: cx - 95*scale, y: base))
    body.line(to: NSPoint(x: cx - 60*scale, y: base + 350*scale))
    body.curve(to: NSPoint(x: cx + 60*scale, y: base + 350*scale), controlPoint1: NSPoint(x: cx - 35*scale, y: base + 405*scale), controlPoint2: NSPoint(x: cx + 35*scale, y: base + 405*scale))
    body.line(to: NSPoint(x: cx + 95*scale, y: base))
    body.close(); suit.setFill(); body.fill()
    rounded(rect(cx-45*scale, base+122*scale, 90*scale, 220*scale), 18*scale, color(0xF8F2E8, 0.98))
    ellipse(rect(cx-62*scale, base+360*scale, 124*scale, 124*scale), skin)
    // hair / robot headset
    ellipse(rect(cx-70*scale, base+420*scale, 140*scale, 78*scale), color(0x2D2A2E,0.9))
    rounded(rect(cx+52*scale, base+405*scale, 18*scale, 42*scale), 8*scale, accent)
    // arms vary
    if pose % 3 == 0 {
        line(NSPoint(x:cx-70*scale,y:base+300*scale), NSPoint(x:cx-190*scale,y:base+230*scale), suit, 34*scale)
        line(NSPoint(x:cx+70*scale,y:base+300*scale), NSPoint(x:cx+190*scale,y:base+265*scale), suit, 34*scale)
    } else if pose % 3 == 1 {
        line(NSPoint(x:cx-70*scale,y:base+300*scale), NSPoint(x:cx-135*scale,y:base+360*scale), suit, 34*scale)
        line(NSPoint(x:cx+70*scale,y:base+300*scale), NSPoint(x:cx+145*scale,y:base+220*scale), suit, 34*scale)
    } else {
        line(NSPoint(x:cx-70*scale,y:base+300*scale), NSPoint(x:cx-165*scale,y:base+260*scale), suit, 34*scale)
        line(NSPoint(x:cx+70*scale,y:base+300*scale), NSPoint(x:cx+135*scale,y:base+350*scale), suit, 34*scale)
    }
    // face simple
    ellipse(rect(cx-27*scale,base+410*scale,10*scale,10*scale), color(0x1C1C1C)); ellipse(rect(cx+18*scale,base+410*scale,10*scale,10*scale), color(0x1C1C1C))
    line(NSPoint(x:cx-20*scale,y:base+390*scale), NSPoint(x:cx+20*scale,y:base+390*scale), color(0x7E4B45), 4*scale)
}
func drawAudience(_ count: Int, _ y: CGFloat, _ seed: Int) {
    for i in 0..<count {
        let x = CGFloat(105 + i * 170 + (seed+i*17)%50)
        let s = CGFloat(0.55 + Double((seed+i)%4)*0.05)
        ellipse(rect(x-38*s,y+82*s,76*s,76*s), color([0xF2C8A2,0xD8A17A,0xF0B58C][(i+seed)%3]))
        rounded(rect(x-58*s,y,116*s,105*s), 20*s, color([0x495869,0x6A5546,0x3E4B3F,0x615A70][(i+seed)%4],0.96))
    }
}
func drawIcon(kind: String, x: CGFloat, y: CGFloat, accent: NSColor) {
    switch kind {
    case "report":
        rounded(rect(x,y,260,190), 26, color(0xFFFFFF,0.30)); for i in 0..<4 { line(NSPoint(x:x+42,y:y+145-CGFloat(i)*34), NSPoint(x:x+220,y:y+145-CGFloat(i)*34), color(0xFFFFFF,0.65), 9) }
        line(NSPoint(x:x+45,y:y+35), NSPoint(x:x+90,y:y+80), accent, 12); line(NSPoint(x:x+90,y:y+80), NSPoint(x:x+205,y:y+55), accent, 12)
    case "request":
        ellipse(rect(x,y+40,86,86), accent); ellipse(rect(x+174,y+40,86,86), color(0xFFFFFF,0.40)); line(NSPoint(x:x+86,y:y+83), NSPoint(x:x+174,y:y+83), color(0xFFFFFF,0.7), 12)
    case "habit":
        rounded(rect(x,y,250,250), 44, color(0xFFFFFF,0.25)); for i in 0..<7 { ellipse(rect(x+30+CGFloat(i%4)*50,y+160-CGFloat(i/4)*60,32,32), i<5 ? accent : color(0xFFFFFF,0.35)) }
    case "money":
        for i in 0..<3 { rounded(rect(x+CGFloat(i)*38,y+CGFloat(i)*35,220,120), 28, color(0xE8D08B,0.75-CGFloat(i)*0.12)); text("¥", rect(x+80+CGFloat(i)*38,y+28+CGFloat(i)*35,70,70), 64, .heavy, color(0x5D4B23)) }
    default:
        rounded(rect(x,y,230,160), 30, color(0xFFFFFF,0.32)); ellipse(rect(x+32,y+72,30,30), accent); line(NSPoint(x:x+82,y:y+105), NSPoint(x:x+190,y:y+105), color(0xFFFFFF,0.7), 10); line(NSPoint(x:x+38,y:y+55), NSPoint(x:x+170,y:y+55), color(0xFFFFFF,0.55), 9)
    }
}
func makeFrame(slug: String, sceneIndex: Int, tag: String, title: String, subtitle: String, mood: String, out: URL) {
    let W: CGFloat=1080, H: CGFloat=1920
    let img=NSImage(size:NSSize(width:W,height:H)); img.lockFocus()
    let palette: [(Int,Int,Int)] = [
        (0x536976,0xBBD2C5,0xFFD166),(0x314755,0xE1EEC3,0xF6C85F),(0x355C7D,0xF8B195,0xFFD166),(0x2B5876,0xDDE9F2,0xA7E0E5),(0x8360C3,0xD7E1EC,0xFFD166)
    ]
    let p=palette[abs(slug.hashValue + sceneIndex) % palette.count]
    drawGradient(NSSize(width:W,height:H), color(p.0), color(p.1))
    // Bright lower safe area, no black band.
    let lower = NSGradient(colors:[color(0xFFFFFF,0.30), color(0xFFFFFF,0.06)])!
    lower.draw(in: rect(0,0,W,520), angle: 90)
    // soft abstract panels / lights
    for i in 0..<7 {
        let a=CGFloat(0.07 + Double((sceneIndex+i)%5)*0.025)
        ellipse(rect(CGFloat((i*173 + sceneIndex*91)%1050)-160, CGFloat(220+i*185), CGFloat(280+(i%3)*80), CGFloat(280+(i%2)*120)), color(0xFFFFFF,a))
    }
    let accent=color(p.2)
    let kind = slug.contains("report") ? "report" : slug.contains("request") ? "request" : slug.contains("habit") ? "habit" : slug.contains("money") ? "money" : "reply"
    // scenario-specific foreground; bottom remains detailed and warm, not black.
    rounded(rect(70,255,940,340), 46, color(0xFFFFFF,0.18))
    drawAudience(5, 290, sceneIndex*11 + slug.count)
    drawPerson(cx: 540 + CGFloat((sceneIndex%3)-1)*42, base: 470, scale: 1.55, suit: color(0x243044,0.94), skin: color(0xE9BD98), accent: accent, pose: sceneIndex)
    drawIcon(kind: kind, x: sceneIndex % 2 == 0 ? 86 : 735, y: 1180, accent: accent)
    // environmental details in lower area to avoid black empty bottom
    for i in 0..<4 { rounded(rect(110+CGFloat(i)*220,80+CGFloat((i+sceneIndex)%2)*30,150,56), 16, color(0xFFFFFF,0.20)) }
    line(NSPoint(x:110,y:690), NSPoint(x:970,y:690), color(0xFFFFFF,0.25), 6)
    text(tag, rect(80, 1550, 920, 50), 38, .heavy, accent)
    text(title, rect(80, 1490, 920, 70), 42, .black, color(0xFFFFFF,0.96))
    text(subtitle.replacingOccurrences(of:"\n", with:" "), rect(100, 1080, 880, 130), 42, .heavy, color(0xFFFFFF,0.22))
    img.unlockFocus()
    if let t=img.tiffRepresentation, let rep=NSBitmapImageRep(data:t), let png=rep.representation(using:.png, properties:[:]) { try? png.write(to: out) }
}

let root=URL(fileURLWithPath:"/Users/yota/Projects/Automation/Youtube/知恵ネキ")
let data=try Data(contentsOf: root.appendingPathComponent("metadata/generated/release_batch_005_009.json"))
let json = try JSONSerialization.jsonObject(with: data) as! [[String:Any]]
for v in json {
    let slug=v["slug"] as! String; let mood=v["mood"] as! String
    let scenes=v["scenes"] as! [[Any]]
    let dir=root.appendingPathComponent("assets/generated/\(slug)_unique/real_images")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (idx, sc) in scenes.enumerated() {
        let tag=sc[0] as! String, title=sc[1] as! String, subtitle=sc[2] as! String
        makeFrame(slug: slug, sceneIndex: idx+1, tag: tag, title: title, subtitle: subtitle, mood: mood, out: dir.appendingPathComponent(String(format:"frame_%02d.png", idx+1)))
    }
    print("generated", slug)
}
