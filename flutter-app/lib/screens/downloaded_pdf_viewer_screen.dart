import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app_colors.dart';
import '../services/download_store.dart';
import '../widgets/space_background.dart';

/// Downloads me save ki gayi PDF ko App ke andar, BINA INTERNET khol deta hai
/// (Web ke "dlview" jaisa: PDF.js se har page canvas par draw hota hai).
Future<void> openDownloadedPdf(BuildContext context, DownloadItem item) async {
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => DownloadedPdfViewerScreen(item: item)),
  );
}

// Viewer ka chhota HTML page. PDF.js aur PDF ke bytes Dart se tukdon me aate
// hain (rx), phir initLib() / openPdf() chalte hain. Pages tabhi draw hote
// hain jab screen ke paas aayen (memory bachane ke liye), door jaane par
// canvas khali kar diya jata hai.
const String _viewerHtml = r'''<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=6.0, user-scalable=yes">
<style>
html,body{margin:0;padding:0;background:__BG__;-webkit-tap-highlight-color:transparent}
#pages{padding:6px 6px 70px}
.pg{position:relative;margin:0 auto 10px;background:#fff;box-shadow:0 1px 6px rgba(0,0,0,.28);border-radius:3px;overflow:hidden}
.pg canvas{display:block}
.pg .num{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);color:#9aa0b4;font:600 28px sans-serif}
#pi{position:fixed;left:50%;bottom:14px;transform:translateX(-50%);background:rgba(20,20,40,.85);color:#fff;font:600 13px sans-serif;padding:6px 14px;border-radius:16px;opacity:0;transition:opacity .25s;pointer-events:none;z-index:9}
#pi.on{opacity:1}
</style></head>
<body><div id="pages"></div><div id="pi"></div>
<script>
var RX={},RXD={},S={doc:null,n:0,scale:1,ver:0,base:{w:595,h:842},io:null,els:[]},piT=0,sT=0,rT=0;
function post(m){try{YSH.postMessage(m)}catch(e){}}
function rx(k,b64,last){
  var bin=atob(b64),n=bin.length,u=new Uint8Array(n),i;
  for(i=0;i<n;i++)u[i]=bin.charCodeAt(i);
  (RX[k]=RX[k]||[]).push(u);
  if(last){
    var a=RX[k],t=0,p=0;
    for(i=0;i<a.length;i++)t+=a[i].length;
    var o=new Uint8Array(t);
    for(i=0;i<a.length;i++){o.set(a[i],p);p+=a[i].length}
    RXD[k]=o;RX[k]=null;
  }
}
function initLib(){
  try{
    var txt=new TextDecoder('utf-8').decode(RXD.lib);
    var s=document.createElement('script');s.text=txt;document.head.appendChild(s);
    RXD.lib=null;
    if(!window.pdfjsLib)throw new Error('pdf.js not available');
    var wurl=URL.createObjectURL(new Blob([RXD.worker],{type:'application/javascript'}));
    pdfjsLib.GlobalWorkerOptions.workerSrc=wurl;
    RXD.worker=null;
  }catch(e){post('error:lib:'+((e&&e.message)||e))}
}
function pageW(){return Math.max(240,document.documentElement.clientWidth-12)*S.scale}
async function openPdf(){
  try{
    if(!window.pdfjsLib){post('error:lib:missing');return}
    var data=RXD.pdf;RXD.pdf=null;
    var task=pdfjsLib.getDocument({data:data});
    S.doc=await task.promise;S.n=S.doc.numPages;
    var p1=await S.doc.getPage(1),v=p1.getViewport({scale:1});
    S.base={w:v.width,h:v.height};
    build();
    post('ready:'+S.n);
  }catch(e){
    var nm=(e&&e.name)||'';
    if(nm==='PasswordException')post('error:password');
    else if(nm==='InvalidPDFException'||nm==='MissingPDFException')post('error:invalid');
    else post('error:other:'+((e&&e.message)||e));
  }
}
function build(){
  var box=document.getElementById('pages');box.innerHTML='';S.els=[];
  if(S.io)S.io.disconnect();
  S.io=new IntersectionObserver(function(es){
    es.forEach(function(e){if(e.isIntersecting)renderPage(e.target);else releasePage(e.target)});
  },{rootMargin:'1400px 0px 1400px 0px'});
  var w=pageW(),r=S.base.h/S.base.w;
  for(var i=1;i<=S.n;i++){
    var d=document.createElement('div');
    d.className='pg';d.dataset.n=i;d._st=0;d._k=0;d._r=r;d._task=null;
    d.style.width=w+'px';d.style.height=(w*r)+'px';
    d.innerHTML='<span class="num">'+i+'</span>';
    box.appendChild(d);S.els.push(d);S.io.observe(d);
  }
  showPi();
}
async function renderPage(el){
  if(el._st||!S.doc)return;
  el._st=1;var tok=++el._k,ver=S.ver;
  try{
    var page=await S.doc.getPage(+el.dataset.n);
    if(el._k!==tok||ver!==S.ver)return;
    var v1=page.getViewport({scale:1}),cssW=pageW(),k=cssW/v1.width;
    var dpr=Math.min(window.devicePixelRatio||1,2),rs=k*dpr,mp=14e6;
    if(v1.width*rs*v1.height*rs>mp)rs=Math.sqrt(mp/(v1.width*v1.height));
    var vp=page.getViewport({scale:rs});
    var cv=document.createElement('canvas');
    cv.width=Math.max(1,Math.floor(vp.width));cv.height=Math.max(1,Math.floor(vp.height));
    var cssH=v1.height*k;
    cv.style.width=cssW+'px';cv.style.height=cssH+'px';
    var task=page.render({canvasContext:cv.getContext('2d'),viewport:vp});
    el._task=task;
    await task.promise;
    if(el._k!==tok||ver!==S.ver){cv.width=0;cv.height=0;return}
    el._task=null;el._r=v1.height/v1.width;
    el.style.width=cssW+'px';el.style.height=cssH+'px';
    el.innerHTML='';el.appendChild(cv);el._st=2;
    try{page.cleanup()}catch(e2){}
  }catch(e){
    if(el._k===tok){el._st=0;el._task=null}
  }
}
function releasePage(el){
  if(!el._st)return;
  el._k++;
  try{if(el._task)el._task.cancel()}catch(e){}
  el._task=null;el._st=0;
  var c=el.querySelector('canvas');
  if(c){c.width=0;c.height=0}
  el.innerHTML='<span class="num">'+el.dataset.n+'</span>';
}
function relayout(){
  if(!S.doc)return;
  var r=(window.scrollY||document.documentElement.scrollTop||0)/Math.max(1,document.documentElement.scrollHeight);
  S.ver++;
  var w=pageW();
  S.els.forEach(function(el){releasePage(el);el.style.width=w+'px';el.style.height=(w*el._r)+'px'});
  window.scrollTo(window.scrollX||0,r*document.documentElement.scrollHeight);
  S.els.forEach(function(el){S.io.unobserve(el);S.io.observe(el)});
}
function zoom(d){
  if(!S.doc)return;
  S.scale=Math.max(0.75,Math.min(3,Math.round((S.scale+d)*100)/100));
  relayout();
  showPi('Zoom '+Math.round(S.scale*100)+'%');
}
function curPage(){
  var mid=window.innerHeight/2,cur=1;
  for(var i=0;i<S.els.length;i++){
    if(S.els[i].getBoundingClientRect().top<=mid)cur=i+1;else break;
  }
  return cur;
}
function showPi(txt){
  var p=document.getElementById('pi');
  p.textContent=txt||(curPage()+' / '+S.n);
  p.className='on';
  clearTimeout(piT);
  piT=setTimeout(function(){p.className=''},1400);
}
window.addEventListener('scroll',function(){
  if(!S.doc||sT)return;
  sT=setTimeout(function(){sT=0;showPi()},120);
},{passive:true});
window.addEventListener('resize',function(){clearTimeout(rT);rT=setTimeout(relayout,250)});
</script></body></html>''';

class DownloadedPdfViewerScreen extends StatefulWidget {
  final DownloadItem item;
  const DownloadedPdfViewerScreen({super.key, required this.item});

  @override
  State<DownloadedPdfViewerScreen> createState() => _DownloadedPdfViewerScreenState();
}

class _DownloadedPdfViewerScreenState extends State<DownloadedPdfViewerScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  bool _landscape = false;
  int _run = 0; // har naye try ka number (purana kaam beech me rukwane ke liye)
  bool _fed = false; // is try me PDF.js / PDF bhejna shuru ho chuka?
  Uint8List? _libBytes;
  Uint8List? _workerBytes;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => spaceBackgroundPause.value++);
    _prepare();
  }

  @override
  void dispose() {
    _run++; // chal raha kaam ruk jaye
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    Future.microtask(() => spaceBackgroundPause.value--);
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _controller = null;
    });
    _prepare();
  }

  Future<void> _prepare() async {
    final run = ++_run;
    _fed = false;
    try {
      final file = await DownloadStore.fileFor(widget.item);
      if (!await file.exists() || await file.length() == 0) {
        _fail('This downloaded PDF file was not found. Please download it again. / यह डाउनलोड की गई PDF फ़ाइल नहीं मिली। कृपया दोबारा डाउनलोड करें।');
        return;
      }
      // Offline viewer (PDF.js) - ek baar download ho chuka ho to turant mil jata hai.
      var lib = await PdfJsAssets.read(PdfJsAssets.libName);
      var worker = await PdfJsAssets.read(PdfJsAssets.workerName);
      if (lib == null || worker == null) {
        await PdfJsAssets.ensure();
        lib = await PdfJsAssets.read(PdfJsAssets.libName);
        worker = await PdfJsAssets.read(PdfJsAssets.workerName);
      }
      if (!mounted || run != _run) return;
      if (lib == null || worker == null) {
        _fail('The offline PDF viewer needs to be set up once with internet. Connect to the internet and tap Try again. / ऑफ़लाइन PDF व्यूअर को एक बार इंटरनेट से तैयार करना होगा। इंटरनेट जोड़कर Try again दबाएँ।');
        return;
      }
      _libBytes = lib;
      _workerBytes = worker;

      final bg = AppTheme.isLight ? const Color(0xFFE4E8F5) : const Color(0xFF1A1A1A);
      final bgCss = AppTheme.isLight ? '#E4E8F5' : '#1A1A1A';
      final c = WebViewController();
      c
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(bg)
        ..addJavaScriptChannel('YSH', onMessageReceived: (JavaScriptMessage m) => _onMessage(m.message, run))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (!mounted || run != _run || _fed) return;
              _fed = true;
              _feed(c, run);
            },
            onWebResourceError: (WebResourceError error) {
              if (error.isForMainFrame == true) _fail('Could not open this PDF. / यह PDF नहीं खुल सकी।');
            },
          ),
        );
      // Android WebView: pinch-zoom chalne do (doosre platform par bekaar - koi nuksan nahi).
      try {
        (c.platform as dynamic).enableZoom(true);
      } catch (_) {}
      if (!mounted || run != _run) return;
      setState(() => _controller = c);
      // https base URL: taaki PDF.js ka worker (blob:) apne hi origin se chal sake.
      await c.loadHtmlString(_viewerHtml.replaceAll('__BG__', bgCss), baseUrl: 'https://ysh-viewer.local/');
    } catch (_) {
      _fail('Could not open this PDF. / यह PDF नहीं खुल सकी।');
    }
  }

  // PDF.js aur PDF ke bytes page ko tukdon me bhejta hai, phir PDF khulwata hai.
  Future<void> _feed(WebViewController c, int run) async {
    try {
      final lib = _libBytes;
      final worker = _workerBytes;
      if (lib == null || worker == null) return;
      if (!await _send(c, 'lib', lib, run)) return;
      if (!await _send(c, 'worker', worker, run)) return;
      await c.runJavaScript('initLib()');
      final bytes = await DownloadStore.fileFor(widget.item).then((f) => f.readAsBytes());
      if (!mounted || run != _run) return;
      if (!await _send(c, 'pdf', bytes, run)) return;
      _libBytes = null; // memory khali
      _workerBytes = null;
      await c.runJavaScript('openPdf()');
    } catch (_) {
      if (mounted && run == _run) {
        _fail('Could not open this PDF. / यह PDF नहीं खुल सकी।');
      }
    }
  }

  // false = beech me screen band ho gayi / naya try shuru ho gaya.
  Future<bool> _send(WebViewController c, String key, Uint8List bytes, int run) async {
    if (bytes.isEmpty) throw Exception('empty $key');
    const chunk = 196608; // 192 KB
    var offset = 0;
    while (offset < bytes.length) {
      if (!mounted || run != _run) return false;
      final end = (offset + chunk < bytes.length) ? offset + chunk : bytes.length;
      final b64 = base64Encode(Uint8List.sublistView(bytes, offset, end));
      final last = end >= bytes.length ? 1 : 0;
      await c.runJavaScript("rx('$key','$b64',$last)");
      offset = end;
    }
    return true;
  }

  void _onMessage(String msg, int run) {
    if (!mounted || run != _run) return;
    if (msg.startsWith('ready:')) {
      if (_loading) setState(() => _loading = false);
    } else if (msg.startsWith('error:')) {
      if (msg == 'error:password') {
        _fail('This PDF is password-protected and cannot be opened here. / यह PDF पासवर्ड से सुरक्षित है, यहाँ नहीं खुल सकती।');
      } else if (msg == 'error:invalid') {
        _fail('This file is not a valid PDF. Please download it again. / यह फ़ाइल सही PDF नहीं है। कृपया दोबारा डाउनलोड करें।');
      } else if (msg.startsWith('error:lib')) {
        _fail('The offline PDF viewer could not start. Connect to the internet once and tap Try again. / ऑफ़लाइन व्यूअर शुरू नहीं हो सका। एक बार इंटरनेट जोड़कर Try again दबाएँ।');
      } else {
        _fail('Could not open this PDF. / यह PDF नहीं खुल सकी।');
      }
    }
  }

  void _zoom(double delta) {
    final c = _controller;
    if (c == null || _loading || _error != null) return;
    try {
      c.runJavaScript('zoom($delta)');
    } catch (_) {}
  }

  // Landscape = full-screen PDF: top bar aur phone ki system bars chhup jati hain.
  void _applyOrientation(bool landscape) {
    if (landscape == _landscape) return;
    _landscape = landscape;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (landscape) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      }
    });
  }

  Widget _landscapeControls() {
    return Positioned(
      top: 8,
      left: 8,
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(28),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
              IconButton(tooltip: 'Zoom out', icon: const Icon(Icons.zoom_out), onPressed: () => _zoom(-0.25)),
              IconButton(tooltip: 'Zoom in', icon: const Icon(Icons.zoom_in), onPressed: () => _zoom(0.25)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    _applyOrientation(landscape);
    final c = _controller;
    return Scaffold(
      backgroundColor: AppC.bg,
      appBar: landscape
          ? null
          : AppBar(
              title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(tooltip: 'Zoom out', icon: const Icon(Icons.zoom_out), onPressed: () => _zoom(-0.25)),
                IconButton(tooltip: 'Zoom in', icon: const Icon(Icons.zoom_in), onPressed: () => _zoom(0.25)),
              ],
            ),
      body: Stack(
        children: [
          if (c != null && _error == null) Positioned.fill(child: WebViewWidget(controller: c)),
          if (landscape) _landscapeControls(),
          if (_loading && _error == null)
            Positioned.fill(
              child: Container(
                color: AppC.bg,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text('Opening PDF... / PDF खुल रही है...', style: TextStyle(color: AppC.text54)),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Positioned.fill(
              child: Container(
                color: AppC.bg,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf, color: AppC.text38, size: 40),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppC.text54)),
                    const SizedBox(height: 14),
                    ElevatedButton(onPressed: _retry, child: const Text('Try again')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
