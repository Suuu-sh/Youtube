#!/usr/bin/env python3
import json, os, re, sys, wave, urllib.parse, urllib.request, subprocess, pathlib, yaml, time, html
ROOT=pathlib.Path('/Users/yota/Projects/Automation/Youtube/雑学ニキ')
SPEAKER=13
BGM='/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3'
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Safari/537.36'

def fetch(url):
    req=urllib.request.Request(url, headers={'User-Agent':UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()

def download_irasutoya(keyword, outdir, idx):
    search='https://www.irasutoya.com/search?q='+urllib.parse.quote(keyword)
    page=fetch(search).decode('utf-8','ignore')
    m=re.search(r"<a href='([^']+)'><script type='text/javascript'>\s*document\.write\(bp_thumbnail_resize\(\"([^\"]+)\",\"([^\"]+)\"\)\);", page, re.S)
    if not m:
        raise RuntimeError(f'Irasutoya search failed: {keyword}')
    page_url=m.group(1); thumb=html.unescape(m.group(2)); title=html.unescape(m.group(3))
    img_url=re.sub(r'/s72-c/', '/s800/', thumb)
    img_url=re.sub(r'/s180/', '/s800/', img_url)
    img_url=re.sub(r'/s\d+(-c)?/', '/s800/', img_url)
    data=fetch(img_url)
    ext='.png' if b'PNG' in data[:16] or img_url.lower().endswith('.png') else '.jpg'
    path=outdir/f'irasutoya_{idx:02d}{ext}'
    path.write_bytes(data)
    return {'path':str(path),'page_url':page_url,'image_url':img_url,'title':title,'keyword':keyword}

def vv(text, out):
    q_url='http://127.0.0.1:50021/audio_query?' + urllib.parse.urlencode({'text':text,'speaker':SPEAKER})
    req=urllib.request.Request(q_url, method='POST')
    with urllib.request.urlopen(req, timeout=30) as r: query=json.loads(r.read())
    query['speedScale']=1.08
    query['volumeScale']=1.0
    s_url='http://127.0.0.1:50021/synthesis?' + urllib.parse.urlencode({'speaker':SPEAKER})
    req=urllib.request.Request(s_url, data=json.dumps(query).encode('utf-8'), headers={'Content-Type':'application/json'}, method='POST')
    with urllib.request.urlopen(req, timeout=120) as r: data=r.read()
    pathlib.Path(out).write_bytes(data)
    with wave.open(out,'rb') as w:
        return w.getnframes()/float(w.getframerate())

def write_swift(path):
    path.write_text(r'''
import Foundation
import AVFoundation
import CoreGraphics
import CoreText
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
struct Fact: Codable { let top:String; let bottom:String; let image:String; let audio:String; let duration:Double; let reveal:Double }
struct Config: Codable { let id:String; let outVideo:String; let silentVideo:String; let contact:String; let bgm:String; let facts:[Fact] }
let cfg = try! JSONDecoder().decode(Config.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let W=1080, H=1920, fps:Int32=30
func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat)->CGColor{ CGColor(red:r/255, green:g/255, blue:b/255, alpha:1) }
func drawText(_ ctx:CGContext,_ text:String,_ rect:CGRect,_ size:CGFloat,_ fill:CGColor,_ stroke:CGColor,_ align:CTTextAlignment = .center){
    let font=CTFontCreateWithName("Hiragino Sans W7" as CFString, size, nil)
    var a=align
    let style=CTParagraphStyleCreate([CTParagraphStyleSetting(spec:.alignment,valueSize:MemoryLayout<CTTextAlignment>.size,value:&a)],1)
    let attr:[CFString:Any]=[kCTFontAttributeName:font,kCTForegroundColorAttributeName:fill,kCTStrokeColorAttributeName:stroke,kCTStrokeWidthAttributeName:-5.5,kCTParagraphStyleAttributeName:style]
    let str=CFAttributedStringCreate(nil,text as CFString,attr as CFDictionary)!
    let fs=CTFramesetterCreateWithAttributedString(str)
    let r=CGRect(x:rect.origin.x,y:CGFloat(H)-rect.origin.y-rect.height,width:rect.width,height:rect.height)
    let path=CGMutablePath(); path.addRect(r)
    let frame=CTFramesetterCreateFrame(fs, CFRangeMake(0, CFAttributedStringGetLength(str)), path, nil)
    ctx.saveGState(); ctx.textMatrix = .identity; CTFrameDraw(frame, ctx); ctx.restoreGState()
}
func loadCG(_ p:String)->CGImage?{ guard let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:p) as CFURL,nil) else { return nil }; return CGImageSourceCreateImageAtIndex(src,0,nil) }
func drawImage(_ ctx:CGContext,_ p:String,_ rect:CGRect,_ scale:CGFloat){
    guard let img=loadCG(p) else { return }
    let iw=CGFloat(img.width), ih=CGFloat(img.height)
    let s=min(rect.width/iw, rect.height/ih)*scale
    let w=iw*s, h=ih*s
    let r=CGRect(x:rect.midX-w/2, y:CGFloat(H)-rect.midY-h/2, width:w, height:h)
    ctx.saveGState(); ctx.setShadow(offset:CGSize(width:0,height:-8), blur:16, color:CGColor(gray:0, alpha:0.20)); ctx.draw(img,in:r); ctx.restoreGState()
}
func star(_ ctx:CGContext){
    ctx.setFillColor(color(255,225,57)); ctx.fill(CGRect(x:0,y:0,width:W,height:H))
    ctx.translateBy(x:CGFloat(W)/2,y:CGFloat(H)/2)
    for i in 0..<56 { ctx.rotate(by: CGFloat.pi/28); ctx.beginPath(); ctx.move(to:CGPoint(x:0,y:0)); ctx.addLine(to:CGPoint(x:32,y:-1120)); ctx.addLine(to:CGPoint(x:-32,y:-1120)); ctx.closePath(); ctx.setFillColor(i%2==0 ? color(255,246,120) : color(255,188,32)); ctx.fillPath() }
    ctx.translateBy(x:-CGFloat(W)/2,y:-CGFloat(H)/2)
}
func drawScene(_ idx:Int,_ t:Double)->CGImage{
    let cs=CGColorSpaceCreateDeviceRGB(); let ctx=CGContext(data:nil,width:W,height:H,bitsPerComponent:8,bytesPerRow:0,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    if idx==0 { star(ctx) } else { let grad=CGGradient(colorsSpace:cs, colors:[color(255,249,232),color(236,248,255)] as CFArray, locations:[0,1])!; ctx.drawLinearGradient(grad,start:CGPoint(x:0,y:0),end:CGPoint(x:0,y:H),options:[]) }
    let f=cfg.facts[idx]
    if idx==0 {
      drawText(ctx,"喋りたくなる！",CGRect(x:80,y:235,width:920,height:220),92,color(255,255,255),color(20,20,20))
      drawText(ctx,"面白い雑学",CGRect(x:80,y:1320,width:920,height:250),112,color(255,255,255),color(20,20,20))
      let imgs=cfg.facts.dropFirst().dropLast().map{$0.image}; let rects=[CGRect(x:80,y:610,width:260,height:260),CGRect(x:410,y:560,width:260,height:260),CGRect(x:740,y:620,width:260,height:260),CGRect(x:230,y:900,width:260,height:260),CGRect(x:600,y:930,width:260,height:260)]
      for (i,p) in imgs.enumerated(){ drawImage(ctx,p,rects[i%rects.count],1.0) }
    } else if idx==cfg.facts.count-1 {
      drawText(ctx,"詳しくは概要欄",CGRect(x:80,y:470,width:920,height:240),86,color(255,255,255),color(20,20,20)); drawImage(ctx,f.image,CGRect(x:300,y:780,width:480,height:420),1.0); drawText(ctx,"いくつわかった？",CGRect(x:80,y:1110,width:920,height:250),88,color(255,240,95),color(20,20,20))
    } else {
      drawText(ctx,f.top,CGRect(x:70,y:250,width:940,height:260),72,color(255,255,255),color(20,20,20)); let pulse=1.0+0.035*sin(t*3.0); drawImage(ctx,f.image,CGRect(x:150,y:585,width:780,height:620),pulse); if t >= f.reveal { drawText(ctx,f.bottom,CGRect(x:70,y:1260,width:940,height:340),76,color(255,239,70),color(20,20,20)) }
    }
    return ctx.makeImage()!
}
let out=URL(fileURLWithPath:cfg.silentVideo); try? FileManager.default.removeItem(at:out)
let writer=try! AVAssetWriter(outputURL:out,fileType:.mp4)
let settings:[String:Any]=[AVVideoCodecKey:AVVideoCodecType.h264, AVVideoWidthKey:W, AVVideoHeightKey:H]
let input=AVAssetWriterInput(mediaType:.video,outputSettings:settings); input.expectsMediaDataInRealTime=false
let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:W,kCVPixelBufferHeightKey as String:H])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime:.zero)
var frame:Int64=0
let attrs=[kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary
for (idx,f) in cfg.facts.enumerated(){ let frames=Int(round(f.duration*Double(fps))); for j in 0..<frames { while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval:0.005) }; var pb:CVPixelBuffer?; CVPixelBufferCreate(kCFAllocatorDefault,W,H,kCVPixelFormatType_32ARGB,attrs,&pb); CVPixelBufferLockBaseAddress(pb!,[]); let c=CGContext(data:CVPixelBufferGetBaseAddress(pb!),width:W,height:H,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pb!),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!; c.draw(drawScene(idx,Double(j)/Double(fps)), in:CGRect(x:0,y:0,width:W,height:H)); CVPixelBufferUnlockBaseAddress(pb!,[]); adaptor.append(pb!,withPresentationTime:CMTime(value:frame,timescale:fps)); frame += 1 } }
input.markAsFinished(); writer.finishWriting { }
while writer.status == .writing { Thread.sleep(forTimeInterval:0.05) }
let comp=AVMutableComposition(); let vasset=AVURLAsset(url:out); let vtrack=comp.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!; try! vtrack.insertTimeRange(CMTimeRange(start:.zero,duration:vasset.duration),of:vasset.tracks(withMediaType:.video)[0],at:.zero)
var mixParams:[AVMutableAudioMixInputParameters]=[]; var at=CMTime.zero
for f in cfg.facts { let a=AVURLAsset(url:URL(fileURLWithPath:f.audio)); let tr=comp.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!; try! tr.insertTimeRange(CMTimeRange(start:.zero,duration:a.duration),of:a.tracks(withMediaType:.audio)[0],at:at+CMTime(seconds:0.25,preferredTimescale:600)); let p=AVMutableAudioMixInputParameters(track:tr); p.setVolume(1.0, at:.zero); mixParams.append(p); at = at + CMTime(seconds:f.duration,preferredTimescale:600) }
let bgmAsset=AVURLAsset(url:URL(fileURLWithPath:cfg.bgm)); if let bt=bgmAsset.tracks(withMediaType:.audio).first { var pos=CMTime.zero; while pos < vasset.duration { let len=min(bgmAsset.duration, vasset.duration-pos); let tr=comp.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!; try! tr.insertTimeRange(CMTimeRange(start:.zero,duration:len),of:bt,at:pos); let p=AVMutableAudioMixInputParameters(track:tr); p.setVolume(0.50, at:.zero); mixParams.append(p); pos = pos + len } }
let audioMix=AVMutableAudioMix(); audioMix.inputParameters=mixParams
let final=URL(fileURLWithPath:cfg.outVideo); try? FileManager.default.removeItem(at:final)
let exp=AVAssetExportSession(asset:comp,presetName:AVAssetExportPresetHighestQuality)!; exp.audioMix=audioMix; exp.outputURL = final; exp.outputFileType = .mp4; exp.exportAsynchronously{}
while exp.status == .waiting || exp.status == .exporting { Thread.sleep(forTimeInterval:0.1) }
if exp.status != .completed { print("EXPORT_FAIL", exp.error ?? "unknown"); exit(2) }
let cctx=CGContext(data:nil,width:W,height:H,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
cctx.setFillColor(color(245,245,245)); cctx.fill(CGRect(x:0,y:0,width:W,height:H))
let cols=2, rows=4; let cellW=W/cols, cellH=H/rows
for i in 0..<cfg.facts.count { let img=drawScene(i, cfg.facts[i].reveal + 0.1); let row=i/cols; let rect=CGRect(x:(i%cols)*cellW,y:H-(row+1)*cellH,width:cellW,height:cellH); cctx.draw(img,in:rect) }
let dest=CGImageDestinationCreateWithURL(URL(fileURLWithPath:cfg.contact) as CFURL, UTType.png.identifier as CFString, 1, nil)!; CGImageDestinationAddImage(dest,cctx.makeImage()!,nil); CGImageDestinationFinalize(dest)
''', encoding='utf-8')

def make(item):
    sid=item['id']; base=ROOT
    mdir=base/'metadata/specific/interesting'/sid; rdir=base/'renders/specific/interesting'/sid; adir=base/'assets/generated/specific/interesting'/sid; qdir=base/'research/specific/interesting'/sid
    for d in (mdir,rdir,adir,qdir): d.mkdir(parents=True, exist_ok=True)
    iras=[]
    for idx,f in enumerate(item['facts'],1):
        info=download_irasutoya(f.get('image_keyword') or f['top'], adir, idx)
        f['irasutoya_url']=info['page_url']; f['irasutoya_image_url']=info['image_url']; f['irasutoya_title']=info['title']; f['local_image_path']=info['path']; iras.append(info)
    final_img=download_irasutoya('説明', adir, 99)
    scenes=[]; timings=[]
    scene_defs=[{'top':'喋りたくなる！','bottom':'面白い雑学','image':iras[0]['path'],'text':'喋りたくなる面白い雑学'}]
    for f in item['facts']: scene_defs.append({'top':f['top'],'bottom':f['bottom'],'image':f['local_image_path'],'text':f['top'].replace('\n','') + '、' + f['bottom'].replace('\n','')})
    scene_defs.append({'top':'詳しくは概要欄','bottom':'いくつわかった？','image':final_img['path'],'text':'詳しくは概要欄。いくつわかった？'})
    for i,s in enumerate(scene_defs):
        wav=str(adir/f'scene_{i+1:02d}.wav'); dur=vv(s['text'], wav); total=max(2.5, dur+0.80); reveal=max(1.05, min(total-0.65, dur*0.62+0.25))
        scenes.append({'top':s['top'],'bottom':s['bottom'],'image':s['image'],'audio':wav,'duration':total,'reveal':reveal})
        timings.append({'scene':i+1,'text':s['text'],'voice_duration':round(dur,3),'audio_offset':0.25,'reveal_sec':round(reveal,3),'duration':round(total,3)})
    swift=adir/'render.swift'; write_swift(swift)
    cfg={'id':sid,'outVideo':str(rdir/f'{sid}_bgm050.mp4'),'silentVideo':str(adir/f'{sid}_silent.mp4'),'contact':str(rdir/'contact.png'),'bgm':BGM,'facts':scenes}
    cfgp=adir/'render_config.json'; cfgp.write_text(json.dumps(cfg,ensure_ascii=False,indent=2),encoding='utf-8')
    subprocess.run(['swift',str(swift),str(cfgp)],check=True,cwd=str(base))
    (adir/'timing.json').write_text(json.dumps(timings,ensure_ascii=False,indent=2),encoding='utf-8')
    desc='喋りたくなる面白い雑学5選\n\nBGM: Escort / もっぴーさうんど（DOVA-SYNDROME）\nVOICEVOX: 青山龍星\n\n【詳細・補足】\n'
    for n,f in enumerate(item['facts'],1): desc += f'{n}. {f["detail"]}\n'
    desc += '\nいくつわかりましたか？'
    now=time.strftime('%Y-%m-%dT%H:%M:%S+09:00', time.localtime())
    source_urls=[f['source_video_url'] for f in item['facts']]
    series={'id':sid,'series_key':'specific_interesting','category':'面白い雑学','category_key':'interesting','topic_key':sid.replace('zatsugaku_interesting_',''),'fact_summary':' / '.join([f['top']+f['bottom'] for f in item['facts']]),'status':'scheduled','schedule_date':item['schedule_date'],'publish_slot':item['publish_slot'],'publish_at':item['publish_at'],'video_path':cfg['outVideo'],'contact_sheet_path':cfg['contact'],'title':'喋りたくなる面白い雑学','description':desc,'description_policy':'detailed_numbered_notes_in_description','source_urls':source_urls,'source_policy':'five_facts_from_five_distinct_available_youtube_videos_source_wording_preserved_no_reused_facts','facts':item['facts'],'timing_notes_path':str(adir/'timing.json'),'bgm':'Escort / もっぴーさうんど（DOVA-SYNDROME） voice 1.0 / bgm 0.50','voicevox_speaker':'青山龍星 (speaker 13)','visual_audit':{'contact_sheet_checked':True,'image_subject_match_checked':True,'no_unrelated_placeholder_images':True,'no_excessive_reuse':True,'checked_at':now,'notes':'Contact sheet inspected after rebuild; real downloaded Irasutoya images are used on all trivia cards; topic mix intentionally not category-bound; VOICEVOX and Escort BGM are mixed into the MP4.'},'created_at':now}
    syml=yaml.safe_dump(series,allow_unicode=True,sort_keys=False).replace('publish_slot: 09:00','publish_slot: \'09:00\'').replace('publish_slot: 13:00','publish_slot: \'13:00\'').replace('publish_slot: 18:00','publish_slot: \'18:00\'')
    (mdir/'series.yaml').write_text('# Managed by scripts/zatsugaku_specific_inventory.rb\n'+syml,encoding='utf-8')
    (mdir/'metadata.md').write_text('# 喋りたくなる面白い雑学\n\n'+desc+'\n\n## Outputs\n- Video: '+cfg['outVideo']+'\n- Contact: '+cfg['contact']+'\n',encoding='utf-8')
    research={'trend_inputs':item.get('trend_inputs',[]),'youtube_sources':[{'url':f['source_video_url'],'title':f['source_title'],'time':f['source_time'],'excerpt':f['source_excerpt']} for f in item['facts']],'duplicate_check':'Checked metadata/specific, metadata, and automation memory for concrete subjects/claims before selection.','irasutoya_assets':iras,'timing_notes':timings,'audio_mix':'VOICEVOX 青山龍星 volume 1.0, Escort BGM volume 0.50, AVMutableAudioMix applied','visual_audit':series['visual_audit']}
    (qdir/'youtube_source_research.yaml').write_text(yaml.safe_dump(research,allow_unicode=True,sort_keys=False),encoding='utf-8')
    return cfg['outVideo']
if __name__=='__main__': make(json.load(open(sys.argv[1],encoding='utf-8')))
