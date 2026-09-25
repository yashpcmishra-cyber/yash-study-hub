import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/image_upload_service.dart';
import '../../models/models.dart';
import '../../utils/open_link.dart';
import '../../widgets/depth_card.dart';
import '../../widgets/net_image.dart';
import 'admin_login_screen.dart';
import 'admin_pdfs_tab.dart';
import 'admin_videos_tab.dart';
import 'admin_mocktests_tab.dart';

/// What the "Edit batch" dialog returns.
class _BatchEditResult {
  final String title;
  final int? price;
  final File? iconFile;
  final int validityMonths; // 0 = lifetime
  _BatchEditResult({required this.title, required this.price, required this.iconFile, required this.validityMonths});
}

/// What the "Change validity" dialog (for ONE student's access) returns.
class _ExtendResult {
  final int months; // months to add (ignored when lifetime is true)
  final bool lifetime;
  _ExtendResult({required this.months, required this.lifetime});
}

/// "Change validity" dialog for one student's access to one batch: add
/// months, or remove the time limit. Its own widget so its text controller
/// is disposed together with the dialog.
class _ExtendAccessDialog extends StatefulWidget {
  final AccessGrantModel grant;
  final String batchTitle;
  final int defaultMonths;
  const _ExtendAccessDialog({required this.grant, required this.batchTitle, required this.defaultMonths});

  @override
  State<_ExtendAccessDialog> createState() => _ExtendAccessDialogState();
}

class _ExtendAccessDialogState extends State<_ExtendAccessDialog> {
  late final TextEditingController _months = TextEditingController(text: widget.defaultMonths > 0 ? widget.defaultMonths.toString() : '1');
  String? _error;

  @override
  void dispose() {
    _months.dispose();
    super.dispose();
  }

  String _currentStatus() {
    final e = widget.grant.expiresAt;
    if (e == null) return 'Now: lifetime access (no time limit).';
    final date = DateFormat('d MMM yyyy').format(e);
    return widget.grant.isExpired ? 'Now: expired on $date.' : 'Now: valid till $date.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF081136),
      title: const Text('Change validity', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.grant.studentEmail}\n${widget.batchTitle}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 8),
            Text(_currentStatus(), style: const TextStyle(color: Color(0xFFFFFF29), fontSize: 12.5)),
            const SizedBox(height: 10),
            TextField(
              controller: _months,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Add months',
                helperText: 'Counted from today, or from the current end date if it is still in the future.',
                helperMaxLines: 3,
                errorText: _error,
                labelStyle: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _ExtendResult(months: 0, lifetime: true)),
          child: const Text('Make lifetime'),
        ),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(_months.text.trim());
            if (n == null || n < 1 || n > 120) {
              setState(() => _error = 'Enter a whole number of months (1 to 120).');
              return;
            }
            Navigator.pop(context, _ExtendResult(months: n, lifetime: false));
          },
          child: const Text('Extend'),
        ),
      ],
    );
  }
}

/// "Edit batch" dialog. It is its own widget so its text controllers are
/// created and disposed together with the dialog (safe, no leaks).
class _EditBatchDialog extends StatefulWidget {
  final BatchModel batch;
  const _EditBatchDialog({required this.batch});

  @override
  State<_EditBatchDialog> createState() => _EditBatchDialogState();
}

class _EditBatchDialogState extends State<_EditBatchDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.batch.title);
  late final TextEditingController _price = TextEditingController(text: widget.batch.price.toString());
  late final TextEditingController _validity = TextEditingController(text: widget.batch.hasValidity ? widget.batch.validityMonths.toString() : '');
  String? _validityError;
  File? _icon;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _validity.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null && mounted) setState(() => _icon = File(img.path));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF081136),
      title: const Text('Edit batch', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              GestureDetector(
                onTap: _pickIcon,
                child: _icon != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_icon!, width: 48, height: 48, fit: BoxFit.cover))
                    : NetImage(url: widget.batch.iconUrl, width: 48, height: 48, fallbackIcon: '🖼️', radius: 10),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickIcon,
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Change icon'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _title, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: _price, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Price', labelStyle: TextStyle(color: Colors.grey))),
            TextField(
              controller: _validity,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Validity in months (empty = lifetime)',
                helperText: 'Applies only to students who get access AFTER you save. Students who already have access keep their own end date.',
                helperMaxLines: 4,
                errorText: _validityError,
                labelStyle: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final vt = _validity.text.trim();
            final months = vt.isEmpty ? 0 : int.tryParse(vt);
            if (months == null || months < 0 || months > 120) {
              setState(() => _validityError = 'Enter a whole number of months (1 to 120), or leave empty for lifetime.');
              return;
            }
            Navigator.pop(
              context,
              _BatchEditResult(title: _title.text.trim(), price: int.tryParse(_price.text.trim()), iconFile: _icon, validityMonths: months),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _auth = AuthService();
  final _fs = FirestoreService();
  final _imageUpload = ImageUploadService();

  // Streams are created once (not on every rebuild).
  late final Stream<List<BatchModel>> _batchesStream = _fs.streamBatches();
  late final Stream<List<AccessRequestModel>> _requestsStream = _fs.streamPendingRequests();
  late final Stream<List<AccessGrantModel>> _grantsStream = _fs.streamGrants();
  late final Stream<List<MockTestAttemptModel>> _attemptsStream = _fs.streamMockAttempts();
  late final Stream<AppConfigModel> _configStream = _fs.streamAppConfig();
  late final Stream<List<BannerModel>> _bannersStream = _fs.streamBanners();
  late Future<int> _installFuture;
  late Future<List<int>> _activeFuture; // [active today, last 7 days, last 30 days]

  File? _batchIconFile;
  File? _appLogoFile;
  File? _bannerImageFile;
  String? _batchIconStatus;
  String? _brandingStatus;
  String? _bannerStatus;
  bool _busy = false; // an upload / save is in progress

  // Controllers live here (not inside build methods) and are disposed below.
  final _grantEmailCtrl = TextEditingController();
  final _grantPhoneCtrl = TextEditingController();
  final _batchTitleCtrl = TextEditingController();
  final _batchPriceCtrl = TextEditingController();
  final _batchValidityCtrl = TextEditingController(); // Add-batch form: months, empty = lifetime
  final _grantMonthsCtrl = TextEditingController(); // Manual grant: months override, empty = batch default
  final _notifyTitleCtrl = TextEditingController();
  final _notifyBodyCtrl = TextEditingController();
  final _brandAppNameCtrl = TextEditingController();
  final _brandTaglineCtrl = TextEditingController();
  final _brandUpiCtrl = TextEditingController();
  final _brandTelegramCtrl = TextEditingController();
  final _brandPaymentTelegramCtrl = TextEditingController();
  final _brandWhatsappCtrl = TextEditingController();
  final _brandYoutubeCtrl = TextEditingController();
  final _bannerLinkCtrl = TextEditingController();
  String? _selectedGrantBatch;
  bool _brandFieldsLoaded = false; // only prefill the text fields once, so admin's in-progress edits aren't overwritten by every live snapshot

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 10, vsync: this);
    _installFuture = _fs.installCount();
    _activeFuture = _loadActiveCounts();
  }

  // Phones that opened the app today / in the last 7 days / in the last 30 days
  // (calendar days, counting today).
  Future<List<int>> _loadActiveCounts() {
    final n = DateTime.now();
    return Future.wait([
      _fs.activeCountSince(DateTime(n.year, n.month, n.day)),
      _fs.activeCountSince(DateTime(n.year, n.month, n.day - 6)),
      _fs.activeCountSince(DateTime(n.year, n.month, n.day - 29)),
    ]);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _grantEmailCtrl.dispose();
    _grantPhoneCtrl.dispose();
    _batchTitleCtrl.dispose();
    _batchPriceCtrl.dispose();
    _batchValidityCtrl.dispose();
    _grantMonthsCtrl.dispose();
    _notifyTitleCtrl.dispose();
    _notifyBodyCtrl.dispose();
    _brandAppNameCtrl.dispose();
    _brandTaglineCtrl.dispose();
    _brandUpiCtrl.dispose();
    _brandTelegramCtrl.dispose();
    _brandPaymentTelegramCtrl.dispose();
    _brandWhatsappCtrl.dispose();
    _brandYoutubeCtrl.dispose();
    _bannerLinkCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String message, {String action = 'Delete'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF081136),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _logout)],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: const Color(0xFFFFFF29),
          labelColor: const Color(0xFFFFFF29),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Stats'),
            Tab(text: 'Grants'),
            Tab(text: 'Batches'),
            Tab(text: 'PDFs'),
            Tab(text: 'Videos'),
            Tab(text: 'Mock Tests'),
            Tab(text: 'Attempts'),
            Tab(text: 'Branding'),
            Tab(text: 'Banners'),
            Tab(text: 'Notify'),
          ],
        ),
      ),
      // Swiping is switched off so a sideways finger-slip while typing can
      // never jump to another tab. Tap a tab title to change tabs.
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _statsTab(),
          _grantsTab(),
          _batchesTab(),
          const AdminPdfsTab(),
          const AdminVideosTab(),
          const AdminMockTestsTab(),
          _attemptsTab(),
          _brandingTab(),
          _bannersTab(),
          _notifyTab(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Access code dialog (after granting access)
  // ------------------------------------------------------------------
  Future<void> _showAccessCodeDialog(String email, String code, {String phone = '', DateTime? expiresAt}) {
    final hasPhone = phone.trim().isNotEmpty;
    final validityNote = expiresAt != null ? ' Your access is valid till ${DateFormat('d MMM yyyy').format(expiresAt)}.' : '';
    final message = 'Yash Study Hub: your access code is $code. Open the app, go to your batch and tap "Check Access", then enter this code with your email ($email).$validityNote';
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF081136),
        title: const Text('Access granted', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasPhone
                  ? 'The student gave a WhatsApp/phone number \u2014 send the code with the button below (they need the email AND this code to unlock):'
                  : 'The student did not give a phone/WhatsApp number \u2014 you can send the code by email (from your own email app), or any other way you can reach this student:',
              style: const TextStyle(color: Colors.grey, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF050B24), borderRadius: BorderRadius.circular(10)),
                child: Text(code, style: const TextStyle(color: Color(0xFFFFFF29), fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 4)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                expiresAt != null ? 'Valid till ${DateFormat('d MMM yyyy').format(expiresAt)}' : 'Lifetime access (no time limit)',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
            if (hasPhone) ...[
              const SizedBox(height: 12),
              Text('Number: $phone', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Code copied')));
            },
            child: const Text('Copy code'),
          ),
          if (hasPhone)
            TextButton(
              onPressed: () async {
                // wa.me needs digits only (no +, spaces, dashes) and a country code.
                var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length == 10) digits = '91$digits'; // Indian number typed without country code
                await openExternalLink(dialogContext, 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
              },
              child: const Text('Open WhatsApp'),
            )
          else
            TextButton(
              onPressed: () async {
                final url = 'mailto:$email?subject=${Uri.encodeComponent('Yash Study Hub access code')}&body=${Uri.encodeComponent(message)}';
                final ok = await openExternalLink(dialogContext, url);
                if (!ok && dialogContext.mounted) {
                  // No email app could be opened — copy everything needed so
                  // the admin can still send it manually.
                  await Clipboard.setData(ClipboardData(text: '$email \u2014 $message'));
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('No email app found \u2014 email + code copied instead, paste it wherever you\u2019ll send it.')),
                    );
                  }
                }
              },
              child: const Text('Email code'),
            ),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Stats
  // ------------------------------------------------------------------
  Widget _statsTab() {
    Widget statColumn(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        );
    void refresh() => setState(() {
          _installFuture = _fs.installCount();
          _activeFuture = _loadActiveCounts();
        });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DepthCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<int>(
              future: _installFuture,
              builder: (context, snap) {
                final loading = snap.connectionState != ConnectionState.done;
                final countText = loading ? '...' : (snap.hasError ? '?' : '${snap.data ?? 0}');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.people, color: Color(0xFFFFFF29)),
                        const SizedBox(height: 6),
                        Text(countText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const Text('App installs (only counting)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        if (snap.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Could not load the count: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                          ),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh, color: Colors.grey),
                      onPressed: refresh,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        DepthCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<int>>(
              future: _activeFuture,
              builder: (context, snap) {
                final loading = snap.connectionState != ConnectionState.done;
                String v(int i) => loading ? '...' : ((snap.hasError || snap.data == null) ? '?' : '${snap.data![i]}');
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.bolt, color: Color(0xFFFFFF29)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Active students (phones that opened the app)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    statColumn(v(0), 'Today'),
                    statColumn(v(1), 'Last 7 days'),
                    statColumn(v(2), 'Last 30 days'),
                  ]),
                  if (snap.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Could not load the count: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'Only phones that have opened the updated app are counted. Reinstall = counted again. / Sirf naye app version wale phones ginte hain.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ]);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Grants
  // ------------------------------------------------------------------
  // [months] = how long the access lasts (0 = lifetime).
  Future<void> _grant(String email, String batchId, {String phone = '', int months = 0}) async {
    try {
      final res = await _fs.grantAccess(email, batchId, months: months);
      if (!mounted) return;
      await _showAccessCodeDialog(email, res.code, phone: phone, expiresAt: res.expiresAt);
    } catch (e) {
      _snack('Could not grant access: $e');
    }
  }

  String _batchTitleFor(List<BatchModel> batches, String id) {
    for (final b in batches) {
      if (b.id == id) return b.title;
    }
    return '(deleted batch)';
  }

  // The batch's own validity (months); 0 = lifetime / batch not found.
  int _batchValidityFor(List<BatchModel> batches, String? id) {
    for (final b in batches) {
      if (b.id == id) return b.validityMonths;
    }
    return 0;
  }

  Future<void> _changeValidity(AccessGrantModel g, String batchTitle, int defaultMonths) async {
    final r = await showDialog<_ExtendResult>(
      context: context,
      builder: (_) => _ExtendAccessDialog(grant: g, batchTitle: batchTitle, defaultMonths: defaultMonths),
    );
    if (r == null) return;
    try {
      if (r.lifetime) {
        await _fs.makeAccessLifetime(g.studentEmail, g.batchId);
        _snack('Now lifetime access');
      } else {
        final until = await _fs.extendAccess(g.studentEmail, g.batchId, r.months);
        _snack('Valid till ${DateFormat('d MMM yyyy').format(until)}');
      }
    } catch (e) {
      _snack('Could not change validity: $e');
    }
  }

  Widget _grantsTab() {
    return StreamBuilder<List<BatchModel>>(
      stream: _batchesStream,
      builder: (context, snap) {
        final batches = snap.data ?? <BatchModel>[];
        _selectedGrantBatch ??= batches.isNotEmpty ? batches.first.id : null;
        if (_selectedGrantBatch != null && !batches.any((b) => b.id == _selectedGrantBatch)) {
          _selectedGrantBatch = batches.isNotEmpty ? batches.first.id : null;
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Pending requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const Text('The student entered their email in the app but doesn\u2019t have access yet \u2014 grant it here in one tap.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 10),
            StreamBuilder<List<AccessRequestModel>>(
              stream: _requestsStream,
              builder: (context, reqSnap) {
                if (reqSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('Could not load requests: ${reqSnap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  );
                }
                final requests = reqSnap.data ?? <AccessRequestModel>[];
                if (requests.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('No pending requests', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                }
                return Column(
                  children: requests
                      .map((r) => DepthCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                r.studentName.isNotEmpty ? '${r.studentName} (${r.studentEmail})' : r.studentEmail,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              subtitle: Text(
                                r.studentPhone.isNotEmpty ? '${r.batchTitle} \u2022 \u{1F4F1} ${r.studentPhone}' : '${r.batchTitle} \u2022 (no phone/WhatsApp number given)',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Grant access',
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    onPressed: () => _grant(r.studentEmail, r.batchId, phone: r.studentPhone, months: _batchValidityFor(batches, r.batchId)),
                                  ),
                                  IconButton(
                                    tooltip: 'Dismiss (payment not received)',
                                    icon: const Icon(Icons.close, color: Colors.redAccent),
                                    onPressed: () async {
                                      try {
                                        await _fs.dismissAccessRequest(r.id);
                                      } catch (e) {
                                        _snack('Could not dismiss: $e');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const Divider(color: Colors.grey, height: 30),
            const Text('Manual grant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(controller: _grantEmailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Student email', labelStyle: TextStyle(color: Colors.grey))),
            const SizedBox(height: 10),
            TextField(controller: _grantPhoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'WhatsApp/phone (optional, if you have it)', labelStyle: TextStyle(color: Colors.grey))),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedGrantBatch,
              dropdownColor: const Color(0xFF081136),
              isExpanded: true,
              hint: const Text('Choose a batch', style: TextStyle(color: Colors.grey)),
              items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.title, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => setState(() => _selectedGrantBatch = v),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _grantMonthsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Validity in months (empty = batch default: ${_batchValidityFor(batches, _selectedGrantBatch) > 0 ? monthsText(_batchValidityFor(batches, _selectedGrantBatch)) : 'lifetime'})',
                helperText: 'Type 0 for lifetime access.',
                labelStyle: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final email = _grantEmailCtrl.text.trim();
                final batchId = _selectedGrantBatch;
                if (email.isEmpty || batchId == null) {
                  _snack('Enter the student email and choose a batch.');
                  return;
                }
                final mt = _grantMonthsCtrl.text.trim();
                int months = _batchValidityFor(batches, batchId);
                if (mt.isNotEmpty) {
                  final n = int.tryParse(mt);
                  if (n == null || n < 0 || n > 120) {
                    _snack('Validity must be a whole number of months (0 = lifetime, or leave empty for the batch default).');
                    return;
                  }
                  months = n;
                }
                final phone = _grantPhoneCtrl.text.trim();
                _grantEmailCtrl.clear();
                _grantPhoneCtrl.clear();
                _grantMonthsCtrl.clear();
                await _grant(email, batchId, phone: phone, months: months);
              },
              child: const Text('Grant access'),
            ),
            const Divider(color: Colors.grey, height: 34),
            const Text('Students who have access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const Text('Tap the red button to take access back (the student is locked out the next time they open the batch).', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 10),
            StreamBuilder<List<AccessGrantModel>>(
              stream: _grantsStream,
              builder: (context, gSnap) {
                if (gSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('Could not load the list: ${gSnap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  );
                }
                if (!gSnap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
                final grants = gSnap.data!;
                if (grants.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Nobody has access yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                }
                return Column(
                  children: grants
                      .map((g) => DepthCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(g.studentEmail, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_batchTitleFor(batches, g.batchId), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text(
                                    g.expiresAt == null
                                        ? 'Lifetime'
                                        : (g.isExpired ? 'Expired on ${DateFormat('d MMM yyyy').format(g.expiresAt!)}' : 'Valid till ${DateFormat('d MMM yyyy').format(g.expiresAt!)}'),
                                    style: TextStyle(color: g.isExpired ? Colors.redAccent : Colors.greenAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Change validity / renew',
                                    icon: const Icon(Icons.event_repeat, color: Color(0xFFFFFF29), size: 20),
                                    onPressed: () => _changeValidity(g, _batchTitleFor(batches, g.batchId), _batchValidityFor(batches, g.batchId)),
                                  ),
                                  IconButton(
                                    tooltip: 'Take access back',
                                    icon: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      final ok = await _confirm('Take access back?', '${g.studentEmail} will no longer be able to open "${_batchTitleFor(batches, g.batchId)}".', action: 'Take back');
                                      if (!ok) return;
                                      try {
                                        await _fs.revokeAccess(g.studentEmail, g.batchId);
                                        _snack('Access taken back');
                                      } catch (e) {
                                        _snack('Could not take access back: $e');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Batches
  // ------------------------------------------------------------------
  Future<void> _addBatch() async {
    if (_busy) return;
    final p = int.tryParse(_batchPriceCtrl.text.trim()) ?? 0;
    if (_batchTitleCtrl.text.trim().isEmpty || p <= 0) {
      _snack('Enter a batch title and a price greater than 0.');
      return;
    }
    final vt = _batchValidityCtrl.text.trim();
    final validityMonths = vt.isEmpty ? 0 : int.tryParse(vt);
    if (validityMonths == null || validityMonths < 0 || validityMonths > 120) {
      _snack('Validity must be a whole number of months (1 to 120), or leave it empty for lifetime.');
      return;
    }
    setState(() {
      _busy = true;
      _batchIconStatus = null;
    });
    String? iconUrl;
    if (_batchIconFile != null) {
      try {
        iconUrl = await _imageUpload.uploadImage(_batchIconFile!);
      } on ImageUploadNotConfiguredException catch (e) {
        if (mounted) setState(() => _batchIconStatus = e.message);
      } catch (e) {
        // The batch still gets added (the icon is optional); the admin sees
        // exactly what happened and can add the icon later with Edit.
        if (mounted) setState(() => _batchIconStatus = 'Icon upload failed ($e) \u2014 the batch was added without an icon. You can add the icon later with the Edit button.');
      }
    }
    try {
      await _fs.addBatch(BatchModel(id: '', title: _batchTitleCtrl.text.trim(), price: p, iconUrl: iconUrl, validityMonths: validityMonths));
      _batchTitleCtrl.clear();
      _batchPriceCtrl.clear();
      _batchValidityCtrl.clear();
      if (mounted) setState(() => _batchIconFile = null);
      _snack('Batch added');
    } catch (e) {
      _snack('Could not add the batch: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editBatch(BatchModel b) async {
    final r = await showDialog<_BatchEditResult>(
      context: context,
      builder: (_) => _EditBatchDialog(batch: b),
    );
    if (r == null) return;
    String? iconUrl;
    if (r.iconFile != null) {
      try {
        iconUrl = await _imageUpload.uploadImage(r.iconFile!);
      } on ImageUploadNotConfiguredException catch (e) {
        _snack(e.message);
      } catch (e) {
        _snack('Icon upload failed: $e');
      }
    }
    try {
      await _fs.updateBatch(b.id, title: r.title.isEmpty ? null : r.title, price: r.price, iconUrl: iconUrl, validityMonths: r.validityMonths);
      _snack('Batch updated');
    } catch (e) {
      _snack('Update failed: $e');
    }
  }

  Future<void> _deleteBatchConfirm(BatchModel b) async {
    final ok = await _confirm(
      'Delete batch?',
      'Delete "${b.title}"? All its PDFs, videos, folders and the students\u2019 access records will be deleted too. This cannot be undone.',
    );
    if (!ok) return;
    try {
      await _fs.deleteBatch(b.id);
      _snack('Batch deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  Widget _batchesTab() {
    Future<void> pickIcon() async {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (img != null && mounted) setState(() => _batchIconFile = File(img.path));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Add new batch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        const Text('Batch icon/picture', style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 6),
        Row(children: [
          GestureDetector(
            onTap: pickIcon,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFF050B24), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade800)),
              child: _batchIconFile != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_batchIconFile!, fit: BoxFit.cover)) : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(onPressed: pickIcon, icon: const Icon(Icons.upload, size: 16), label: const Text('Upload from phone')),
        ]),
        if (_batchIconStatus != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_batchIconStatus!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11))),
        const SizedBox(height: 14),
        TextField(controller: _batchTitleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Batch title', labelStyle: TextStyle(color: Colors.grey))),
        TextField(controller: _batchPriceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Price (number only)', labelStyle: TextStyle(color: Colors.grey))),
        TextField(
          controller: _batchValidityCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Validity in months (empty = lifetime)',
            helperText: 'How long a student keeps access after you grant it, e.g. 6.',
            labelStyle: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _busy ? null : _addBatch,
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add batch'),
        ),
        const Divider(color: Colors.grey, height: 34),
        const Text('Existing batches', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        StreamBuilder<List<BatchModel>>(
          stream: _batchesStream,
          builder: (context, snap) {
            if (snap.hasError) return Text('Could not load batches: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12));
            if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
            final batches = snap.data!;
            if (batches.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No batch yet', style: TextStyle(color: Colors.grey, fontSize: 12)));
            return Column(
              children: batches
                  .map((b) => DepthCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: NetImage(url: b.iconUrl, width: 40, height: 40, fallbackIcon: '📁', radius: 8),
                          title: Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text('\u20b9${b.price} \u00b7 ${b.videos} videos \u00b7 ${b.pdfs} PDFs \u00b7 ${b.hasValidity ? monthsText(b.validityMonths) : 'Lifetime'}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit, color: Colors.grey, size: 18), onPressed: () => _editBatch(b)),
                              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deleteBatchConfirm(b)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Attempts
  // ------------------------------------------------------------------
  Widget _attemptsTab() {
    return StreamBuilder<List<MockTestAttemptModel>>(
      stream: _attemptsStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load attempts: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final attempts = snap.data!;
        if (attempts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No mock test attempts yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Latest ${attempts.length} attempts', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            ...attempts.map((a) => DepthCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(a.mockTestTitle.isEmpty ? '(test id: ${a.mockTestId})' : a.mockTestTitle, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text(
                      a.submittedAt != null ? '${a.studentEmail} \u2022 ${DateFormat('d MMM, h:mm a').format(a.submittedAt!)}' : a.studentEmail,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    trailing: Text('${a.score}/${a.total}', style: TextStyle(color: a.total > 0 && a.score >= a.total / 2 ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Branding
  // ------------------------------------------------------------------
  Future<void> _pickLogo() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null && mounted) setState(() => _appLogoFile = File(img.path));
  }

  Future<void> _uploadLogo() async {
    if (_appLogoFile == null || _busy) return;
    setState(() => _busy = true);
    try {
      final url = await _imageUpload.uploadImage(_appLogoFile!);
      await _fs.setAppLogoUrl(url);
      if (mounted) {
        setState(() {
          _brandingStatus = 'Logo updated \u2014 it\u2019ll show across the app instantly.';
          _appLogoFile = null;
        });
      }
    } on ImageUploadNotConfiguredException catch (e) {
      if (mounted) setState(() => _brandingStatus = e.message);
    } catch (e) {
      if (mounted) setState(() => _brandingStatus = 'Logo upload failed: $e \u2014 please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveBrandingText(AppConfigModel current) async {
    try {
      await _fs.setAppConfig(current.copyWith(
        appName: _brandAppNameCtrl.text.trim().isEmpty ? null : _brandAppNameCtrl.text.trim(),
        tagline: _brandTaglineCtrl.text.trim().isEmpty ? null : _brandTaglineCtrl.text.trim(),
        upiId: _brandUpiCtrl.text.trim().isEmpty ? null : _brandUpiCtrl.text.trim(),
        telegramUrl: _brandTelegramCtrl.text.trim().isEmpty ? null : _brandTelegramCtrl.text.trim(),
        paymentTelegramUrl: _brandPaymentTelegramCtrl.text.trim().isEmpty ? null : _brandPaymentTelegramCtrl.text.trim(),
        whatsappUrl: _brandWhatsappCtrl.text.trim().isEmpty ? null : _brandWhatsappCtrl.text.trim(),
        youtubeUrl: _brandYoutubeCtrl.text.trim().isEmpty ? null : _brandYoutubeCtrl.text.trim(),
      ));
      _snack('Saved \u2014 it shows up across the whole app right away');
    } catch (e) {
      _snack('Save failed: $e');
    }
  }

  Widget _brandingTab() {
    return StreamBuilder<AppConfigModel>(
      stream: _configStream,
      builder: (context, snap) {
        final cfg = snap.data ?? const AppConfigModel();
        // Prefill the editable text fields exactly once (first snapshot),
        // so the admin's own typing isn't overwritten on every live update.
        if (!_brandFieldsLoaded && snap.hasData) {
          _brandAppNameCtrl.text = cfg.appName;
          _brandTaglineCtrl.text = cfg.tagline;
          _brandUpiCtrl.text = cfg.upiId;
          _brandTelegramCtrl.text = cfg.telegramUrl;
          _brandPaymentTelegramCtrl.text = cfg.paymentTelegramUrl;
          _brandWhatsappCtrl.text = cfg.whatsappUrl;
          _brandYoutubeCtrl.text = cfg.youtubeUrl;
          _brandFieldsLoaded = true;
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('App logo (shown on splash screen + home header)', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: _appLogoFile != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_appLogoFile!, fit: BoxFit.cover))
                    : (cfg.logoUrl != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(cfg.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.school)))
                        : Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.school))),
              ),
              const SizedBox(width: 14),
              Expanded(child: OutlinedButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.upload, size: 16), label: const Text('Choose new logo'))),
            ]),
            if (_brandingStatus != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_brandingStatus!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: (_appLogoFile == null || _busy) ? null : _uploadLogo, child: const Text('Save logo')),
            const Divider(color: Colors.grey, height: 34),
            const Text('App name, tagline, UPI ID & social links', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('Changes show up in the whole app right away \u2014 no rebuild needed. Double-check the UPI ID: students pay to it.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 10),
            TextField(controller: _brandAppNameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'App name', labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: _brandTaglineCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Tagline', labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: _brandUpiCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'UPI ID', labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: _brandTelegramCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Telegram URL', helperText: 'Official channel — shown on Home', labelStyle: TextStyle(color: Colors.grey), helperStyle: TextStyle(color: Colors.grey, fontSize: 11))),
            TextField(controller: _brandPaymentTelegramCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Payment Telegram URL', helperText: 'Where students send their payment screenshot (can be different from above)', labelStyle: TextStyle(color: Colors.grey), helperStyle: TextStyle(color: Colors.grey, fontSize: 11))),
            TextField(controller: _brandWhatsappCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'WhatsApp URL', labelStyle: TextStyle(color: Colors.grey))),
            TextField(controller: _brandYoutubeCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'YouTube URL', labelStyle: TextStyle(color: Colors.grey))),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => _saveBrandingText(cfg), child: const Text('Save')),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Banners
  // ------------------------------------------------------------------
  Future<void> _pickBannerImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (img != null && mounted) setState(() => _bannerImageFile = File(img.path));
  }

  Future<void> _uploadBanner() async {
    if (_bannerImageFile == null || _busy) return;
    setState(() => _busy = true);
    try {
      final url = await _imageUpload.uploadImage(_bannerImageFile!);
      await _fs.addBanner(url, linkUrl: _bannerLinkCtrl.text.trim().isEmpty ? null : _bannerLinkCtrl.text.trim());
      if (mounted) {
        setState(() {
          _bannerStatus = 'Banner added \u2014 it shows on the Home screen right away.';
          _bannerImageFile = null;
          _bannerLinkCtrl.clear();
        });
      }
    } on ImageUploadNotConfiguredException catch (e) {
      if (mounted) setState(() => _bannerStatus = e.message);
    } catch (e) {
      if (mounted) setState(() => _bannerStatus = 'Banner upload failed: $e \u2014 please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteBannerConfirm(BannerModel b) async {
    final ok = await _confirm('Delete banner?', 'This banner will be removed from the Home screen slider.');
    if (!ok) return;
    try {
      await _fs.deleteBanner(b.id);
      _snack('Banner deleted');
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  Widget _bannersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Home Screen \u2014 auto-scroll banner slider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text(
          '16:9 landscape images look best (for example 1280\u00d7720). A new banner shows on the Home screen right away, no rebuild needed.',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickBannerImage,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF050B24), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade800)),
              child: _bannerImageFile != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_bannerImageFile!, fit: BoxFit.cover))
                  : const Center(child: Icon(Icons.add_photo_alternate, color: Colors.grey, size: 32)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _pickBannerImage, icon: const Icon(Icons.upload, size: 16), label: const Text('Choose 16:9 image from phone')),
        const SizedBox(height: 10),
        TextField(
          controller: _bannerLinkCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Link (optional \u2014 opens when the banner is tapped)', labelStyle: TextStyle(color: Colors.grey)),
        ),
        if (_bannerStatus != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_bannerStatus!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: (_bannerImageFile == null || _busy) ? null : _uploadBanner, child: const Text('Add banner')),
        const Divider(color: Colors.grey, height: 34),
        const Text('Current banners', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        StreamBuilder<List<BannerModel>>(
          stream: _bannersStream,
          builder: (context, snap) {
            if (snap.hasError) return Text('Could not load banners: ${snap.error}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12));
            if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
            final banners = snap.data!;
            if (banners.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No banner yet \u2014 add one above.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              );
            }
            return Column(
              children: banners
                  .map((b) => DepthCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: NetImage(url: b.imageUrl, width: 64, height: 36, fallbackIcon: '🖼️', radius: 6),
                          title: Text(b.linkUrl ?? '(no link)', style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deleteBannerConfirm(b)),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Notify
  // ------------------------------------------------------------------
  Future<void> _sendNotification() async {
    final title = _notifyTitleCtrl.text.trim();
    final body = _notifyBodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Please enter both a title and a message.');
      return;
    }
    try {
      await _fs.sendNotification(title, body).timeout(const Duration(seconds: 12));
      _notifyTitleCtrl.clear();
      _notifyBodyCtrl.clear();
      _snack('Saved \u2014 students\u2019 phones get the push notification within about 5-10 minutes.');
    } catch (e) {
      _snack('Could not send: $e');
    }
  }

  Widget _notifyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Send a notification to all students\u2019 phones', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        TextField(controller: _notifyTitleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Notification title', labelStyle: TextStyle(color: Colors.grey))),
        TextField(controller: _notifyBodyCtrl, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Message', labelStyle: TextStyle(color: Colors.grey))),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _sendNotification, child: const Text('Send to all students')),
        const SizedBox(height: 10),
        const Text(
          'It appears in the app\u2019s Notifications list straight away. The push to phones is sent by the free GitHub automation, which checks every few minutes.',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}
