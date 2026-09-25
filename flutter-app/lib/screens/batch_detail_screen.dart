import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../utils/open_link.dart';
import '../widgets/net_image.dart';
import '../widgets/state_views.dart';
import 'pdf_viewer_screen.dart';
import 'video_player_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  final BatchModel batch;
  const BatchDetailScreen({super.key, required this.batch});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final _fs = FirestoreService();
  late final Stream<AppConfigModel> _cfgStream = _fs.streamAppConfig();
  late final Stream<List<VideoFolderModel>> _videoFoldersStream = _fs.streamVideoFolders(widget.batch.id);
  late final Stream<List<PdfFolderModel>> _pdfFoldersStream = _fs.streamFolders(type: 'batch', batchId: widget.batch.id);

  bool _checked = false;
  bool _unlocked = false;
  bool _busy = false;
  String? _loadError;
  // Batch validity (time limit). _expiresAt = when this student's access
  // runs out (null = lifetime). _expired = the student HAD access but its
  // time is over, so the locked screen shows a "renew" notice.
  bool _expired = false;
  DateTime? _expiresAt;
  // Name + email now come from the student's account (login is mandatory
  // app-wide) instead of being typed by hand each time — same email the
  // admin sees in Firestore, so "Grant access" still works exactly as
  // before, just with one less chance of a typo locking the student out.
  String _name = '';
  String _email = '';
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _checkMsg;

  @override
  void initState() {
    super.initState();
    _loadEmailAndCheck();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Checks (on opening the screen) whether this student's account already
  // has access. Never leaves the screen stuck on a spinner: if the check
  // fails (offline etc.) a "Try again" message is shown instead.
  Future<void> _loadEmailAndCheck() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      _email = (user?.email ?? '').trim();
      final profile = user != null ? await FirestoreService().getStudentProfile(user.uid) : null;
      _name = profile?.name ?? '';
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('access_code_${widget.batch.id}') ?? '';
      _codeController.text = savedCode;
      if (_email.isNotEmpty) {
        final res = await _fs.checkAccess(_email, widget.batch.id, savedCode);
        if (!mounted) return;
        if (res.expired) {
          // Empty the code box so the student can ask for a renewal (empty
          // code = "send request"). The saved code stays on the phone: if the
          // admin just extends this same access, the batch unlocks by itself.
          _codeController.clear();
        }
        setState(() {
          _unlocked = res.granted;
          _expired = res.expired;
          _expiresAt = res.expiresAt;
          _checked = true;
          _loadError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _checked = true;
          _loadError = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checked = true;
        _loadError = "Couldn't check your access. Please check your internet connection and try again.";
      });
    }
  }

  Future<void> _checkAccess() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    if (_email.isEmpty) {
      setState(() => _checkMsg = 'Please log in again — your account email could not be read. / Dobara login karo.');
      return;
    }
    setState(() {
      _busy = true;
      _checkMsg = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final res = await _fs.checkAccess(_email, widget.batch.id, code);
      if (!mounted) return;
      if (res.granted) {
        await prefs.setString('access_code_${widget.batch.id}', code);
        if (!mounted) return;
        setState(() {
          _unlocked = true;
          _expired = false;
          _expiresAt = res.expiresAt;
          _busy = false;
        });
        return;
      }
      if (res.expired && code.isNotEmpty) {
        // Right code, but the time limit is over. (With an EMPTY code the
        // normal request flow below runs — that is how a student asks for a renewal.)
        _codeController.clear();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _expired = true;
          _expiresAt = res.expiresAt;
          _checkMsg = 'Your access has expired. To renew: pay again, send the screenshot on Telegram, then tap "Check Access" with the code box empty. / Access khatam ho gaya. Renew ke liye dobara pay karo, screenshot Telegram par bhejo, phir code khaali chhodkar "Check Access" dabao.';
        });
        return;
      }
      if (code.isEmpty) {
        // No code yet: tell the admin this student has paid / wants access.
        // (A wrong code does NOT create another request.)
        String message = 'Request sent — send your payment screenshot on Telegram so admin can verify. / Request bhej di — apni payment screenshot Telegram par bhejo verify ke liye.';
        try {
          await _fs
              .submitAccessRequest(_email, widget.batch.id, widget.batch.title, phone: _phoneController.text.trim(), name: _name)
              .timeout(const Duration(seconds: 12));
        } on TimeoutException {
          message = 'Request saved — it will be sent as soon as you are back online. / Request save ho gayi — online aate hi bhej di jaayegi.';
        }
        if (!mounted) return;
        setState(() {
          _busy = false;
          _checkMsg = 'After payment, admin will give you an access code — enter that too. / Payment ke baad admin tumhe access code dega — wo bhi yahan daalo.';
        });
        _snack(message);
      } else {
        setState(() {
          _busy = false;
          _checkMsg = 'Code didn’t match. Confirm your code with the admin, or wait a bit if it hasn’t been granted yet. / Code match nahi hua. Admin se confirm karo, ya thoda wait karo agar abhi tak grant nahi hua.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _checkMsg = 'Something went wrong. Please check your internet connection and try again.';
      });
    }
  }

  Future<void> _copyUpiId(AppConfigModel cfg) async {
    await Clipboard.setData(ClipboardData(text: cfg.upiId));
    _snack('UPI ID copied! Paste it in your payment app (GPay/PhonePe/Paytm) and pay \u20b9${widget.batch.price}. / UPI ID copy ho gayi! Apne payment app mein paste karke \u20b9${widget.batch.price} pay karo.');
  }

  Widget _unlockStep(String number, String en, String hi, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFFFFF29), shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(en, style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text(hi, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!_checked) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null && !_unlocked) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white38, size: 36),
              const SizedBox(height: 10),
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _checked = false;
                    _loadError = null;
                  });
                  _loadEmailAndCheck();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else if (_unlocked) {
      body = _unlockedContent();
    } else {
      body = _lockedContent();
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.batch.title)),
      body: body,
    );
  }

  Widget _lockedContent() {
    return StreamBuilder<AppConfigModel>(
      stream: _cfgStream,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data ?? const AppConfigModel();
        // Scrollable, so the fields stay reachable when the keyboard is open
        // or on small screens.
        return Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                const Text('This batch is locked', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('यह बैच लॉक है', style: TextStyle(color: Colors.grey, fontSize: 13)),
                if (_expired) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x33FF9800),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent),
                    ),
                    child: Text(
                      _expiresAt != null
                          ? '⏰ Your access ended on ${DateFormat('d MMM yyyy').format(_expiresAt!)}. Renew below to unlock again. / आपका एक्सेस ${DateFormat('d MMM yyyy').format(_expiresAt!)} को खत्म हो गया। दोबारा अनलॉक करने के लिए नीचे रिन्यू करें।'
                          : '⏰ Your access to this batch has ended. Renew below to unlock again. / इस बैच का आपका एक्सेस खत्म हो गया। दोबारा अनलॉक करने के लिए नीचे रिन्यू करें।',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Amount to pay / भुगतान की राशि: ₹${widget.batch.price}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (widget.batch.hasValidity)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Validity / वैधता: ${monthsText(widget.batch.validityMonths)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _copyUpiId(cfg),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF081136),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFFF29), width: 1),
                    ),
                    child: Column(children: [
                      const Text('UPI ID \u00b7 tap to copy / कॉपी करने के लिए टैप करें', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cfg.upiId, style: const TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 6),
                          const Text('📋', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF081136), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('How to unlock / अनलॉक कैसे करें', style: TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      _unlockStep('1', 'Tap the UPI ID above to copy it.', 'ऊपर UPI ID पर टैप करके कॉपी करें।'),
                      _unlockStep('2', 'Paste it in your payment app (GPay / PhonePe / Paytm) and pay ₹${widget.batch.price}.', 'अपने पेमेंट ऐप में पेस्ट करके ₹${widget.batch.price} का भुगतान करें।'),
                      _unlockStep('3', 'Send your payment screenshot on Telegram.', 'अपनी पेमेंट स्क्रीनशॉट Telegram पर भेजें।'),
                      _unlockStep('4', 'Come back here and tap "Check Access" (enter the code below once admin shares it).', 'यहाँ वापस आकर "Check Access" दबाएँ (admin से code milte hi neeche daal dena)।', isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => openExternalLink(context, cfg.paymentTelegramUrl),
                  icon: const Icon(Icons.send, size: 18),
                  label: Text('Send screenshot on Telegram\nTelegram पर स्क्रीनशॉट भेजें', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AABEE),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF081136), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFFFFF29), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_name.isNotEmpty ? _name : 'Student', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Pay with this email — access unlocks on this account automatically. / Isi email se pay karo — access khud is account par unlock ho jaayega.', style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'WhatsApp number (optional)', helperText: 'So admin can send your code', labelStyle: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Access code (admin will share it) / एक्सेस कोड', labelStyle: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _busy ? null : _checkAccess,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Check Access'),
                ),
                if (_checkMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_checkMsg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // "Valid till 24 Sep 2026 · 12 days left" under "Access granted". Turns
  // orange (with a renew hint) in the last 7 days.
  Widget _validityLine() {
    final exp = _expiresAt!;
    final daysLeft = exp.difference(DateTime.now()).inDays;
    final soon = daysLeft <= 7;
    final left = daysLeft <= 0 ? 'ends today' : (daysLeft == 1 ? '1 day left' : '$daysLeft days left');
    final date = DateFormat('d MMM yyyy').format(exp);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 21),
      child: Text(
        soon ? 'Valid till $date \u00b7 $left \u2014 contact admin to renew / renew ke liye admin se baat karo' : 'Valid till $date \u00b7 $left',
        style: TextStyle(color: soon ? Colors.orangeAccent : Colors.grey, fontSize: 11.5),
      ),
    );
  }

  Widget _unlockedContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Text('✅', style: TextStyle(fontSize: 15)), SizedBox(width: 6), Text('Access granted', style: TextStyle(color: Colors.green))]),
                  if (_expiresAt != null) _validityLine(),
                ],
              ),
            ),
          ),
          const TabBar(
            indicatorColor: Color(0xFFFFFF29),
            labelColor: Color(0xFFFFFF29),
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: 'Videos'), Tab(text: 'PDFs')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                StreamBuilder<List<VideoFolderModel>>(
                  stream: _videoFoldersStream,
                  builder: (context, folderSnap) {
                    if (folderSnap.hasError) return ErrorView(error: folderSnap.error);
                    if (!folderSnap.hasData) return const LoadingView();
                    final folders = folderSnap.data!;
                    if (folders.isEmpty) return const EmptyView('No video folder in this batch yet');
                    return ListView(
                      children: folders
                          .map((f) => ExpansionTile(
                                iconColor: const Color(0xFFFFFF29),
                                collapsedIconColor: Colors.grey,
                                leading: const Text('📁', style: TextStyle(fontSize: 20)),
                                title: Text(f.name, style: const TextStyle(color: Colors.white)),
                                children: [
                                  StreamBuilder<List<VideoModel>>(
                                    stream: _fs.streamVideosInFolder(f.id),
                                    builder: (context, videoSnap) {
                                      if (videoSnap.hasError) return const Padding(padding: EdgeInsets.all(12), child: Text("Couldn't load videos.", style: TextStyle(color: Colors.grey, fontSize: 12)));
                                      if (!videoSnap.hasData) return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                                      final videos = videoSnap.data!;
                                      if (videos.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('Empty', style: TextStyle(color: Colors.grey, fontSize: 12)));
                                      return Column(
                                        children: videos
                                            .map((v) => ListTile(
                                                  dense: true,
                                                  leading: NetImage(url: v.thumbUrl, width: 56, height: 34, fallbackIcon: '🎬', radius: 6),
                                                  title: Text(v.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                                  onTap: () => Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => VideoPlayerScreen(youtubeUrl: v.youtubeLink, title: v.title, allowExternalOpen: false)),
                                                  ),
                                                ))
                                            .toList(),
                                      );
                                    },
                                  ),
                                ],
                              ))
                          .toList(),
                    );
                  },
                ),
                StreamBuilder<List<PdfFolderModel>>(
                  stream: _pdfFoldersStream,
                  builder: (context, folderSnap) {
                    if (folderSnap.hasError) return ErrorView(error: folderSnap.error);
                    if (!folderSnap.hasData) return const LoadingView();
                    final folders = folderSnap.data!;
                    if (folders.isEmpty) return const EmptyView('No PDF folder in this batch yet');
                    return ListView(
                      children: folders
                          .map((f) => ExpansionTile(
                                iconColor: const Color(0xFFFFFF29),
                                collapsedIconColor: Colors.grey,
                                leading: const Text('📁', style: TextStyle(fontSize: 20)),
                                title: Text(f.name, style: const TextStyle(color: Colors.white)),
                                children: [
                                  StreamBuilder<List<PdfModel>>(
                                    stream: _fs.streamPdfsInFolder(f.id),
                                    builder: (context, pdfSnap) {
                                      if (pdfSnap.hasError) return const Padding(padding: EdgeInsets.all(12), child: Text("Couldn't load PDFs.", style: TextStyle(color: Colors.grey, fontSize: 12)));
                                      if (!pdfSnap.hasData) return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                                      final pdfs = pdfSnap.data!;
                                      if (pdfs.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('Empty', style: TextStyle(color: Colors.grey, fontSize: 12)));
                                      return Column(
                                        children: pdfs
                                            .map((p) => ListTile(
                                                  dense: true,
                                                  leading: NetImage(url: p.iconUrl, width: 34, height: 34, fallbackIcon: '📄', radius: 6),
                                                  title: Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                                  onTap: () => openPdfInApp(context, link: p.driveLink, title: p.title, allowExternalOpen: false),
                                                ))
                                            .toList(),
                                      );
                                    },
                                  ),
                                ],
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
