import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/query_model.dart';
import '../services/firestore_service.dart';
import '../services/queries_service.dart';
import '../services/query_seen_store.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';

/// Cuts anything beyond [max] words (typing AND pasting), so the student can
/// never go over the limit.
class _WordLimitFormatter extends TextInputFormatter {
  final int max;
  _WordLimitFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final matches = RegExp(r'\S+').allMatches(newValue.text).toList();
    if (matches.length <= max) return newValue;
    final end = matches[max - 1].end;
    return TextEditingValue(
      text: newValue.text.substring(0, end),
      selection: TextSelection.collapsed(offset: end),
    );
  }
}

/// Student side of "Queries": write a doubt (max 100 words), see own doubts
/// and the admin's replies. Doubts older than 20 days are deleted
/// automatically from Firebase.
class QueriesScreen extends StatefulWidget {
  const QueriesScreen({super.key});

  @override
  State<QueriesScreen> createState() => _QueriesScreenState();
}

class _QueriesScreenState extends State<QueriesScreen> {
  final _svc = QueriesService();
  final _ctrl = TextEditingController();
  final User? _user = FirebaseAuth.instance.currentUser;
  late final Stream<List<QueryModel>> _stream =
      _user == null ? const Stream<List<QueryModel>>.empty() : _svc.streamMine(_user!.uid);
  String _name = '';
  bool _sending = false;
  List<QueryModel> _latest = const [];
  String _markedKey = ''; // replies already saved as "seen"

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadName() async {
    final u = _user;
    if (u == null) return;
    try {
      final p = await FirestoreService().getStudentProfile(u.uid);
      if (mounted) setState(() => _name = (p?.name ?? '').trim());
    } catch (_) {
      // name stays empty - the email is saved with the doubt anyway
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    final u = _user;
    if (u == null || _sending) return;
    final words = countWords(_ctrl.text);
    if (words == 0) {
      _snack('Write your doubt first. / पहले अपना डाउट लिखें।');
      return;
    }
    if (words > kQueryMaxWords) {
      _snack('Doubt can be at most $kQueryMaxWords words. / डाउट $kQueryMaxWords शब्दों से ज़्यादा नहीं हो सकता।');
      return;
    }
    if (_latest.where((q) => !q.answered).length >= kQueryMaxPending) {
      _snack('You already have $kQueryMaxPending pending doubts. Send a new one after you get a reply. / आपके $kQueryMaxPending डाउट पेंडिंग हैं। जवाब आने के बाद नया भेजें।');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final email = (u.email ?? '').trim();
      final name = _name.isNotEmpty ? _name : (email.contains('@') ? email.split('@').first : 'Student');
      await _svc.submit(uid: u.uid, name: name, email: email, text: _ctrl.text).timeout(const Duration(seconds: 15));
      _ctrl.clear();
      _snack('Doubt sent ✅ / डाउट भेज दिया गया ✅');
    } on TimeoutException {
      // Firestore keeps the write and sends it when the net is back.
      _ctrl.clear();
      _snack('Slow internet. Your doubt will be sent automatically when the net is back, do not send it again. / नेट स्लो है। नेट आते ही डाउट अपने आप चला जाएगा, दोबारा न भेजें।');
    } on FirebaseException catch (e) {
      _snack(e.code == 'permission-denied'
          ? 'Could not send doubt (permission). Please tell the admin. / डाउट नहीं भेजा जा सका (permission)। एडमिन को बताएं।'
          : 'Could not send doubt. Please try again. / डाउट नहीं भेजा जा सका। दोबारा कोशिश करें।');
    } catch (_) {
      _snack('Could not send doubt. Check your internet and try again. / डाउट नहीं भेजा जा सका। इंटरनेट जाँचकर दोबारा कोशिश करें।');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(appBar: AppBar(title: const Text('Queries / सवाल')), body: const EmptyView('Please log in to ask a doubt.\nडाउट पूछने के लिए लॉगिन करें।'));
    }
    final words = countWords(_ctrl.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Queries / सवाल')),
      body: StreamBuilder<List<QueryModel>>(
        stream: _stream,
        builder: (context, snap) {
          final list = snap.data ?? const <QueryModel>[];
          _latest = list;
          // The student is looking at the list = these replies are seen
          // (clears the red dot on the Home screen).
          if (snap.hasData) {
            final key = list.where((q) => q.answered).map((q) => q.seenKey).join(',');
            if (key != _markedKey) {
              _markedKey = key;
              QuerySeenStore.markSeen(list);
            }
          }
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(14),
            children: [
              // ---- write a doubt ----
              DepthCard(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Write your doubt / अपना डाउट लिखें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ctrl,
                        minLines: 3,
                        maxLines: 6,
                        enabled: !_sending,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [_WordLimitFormatter(kQueryMaxWords)],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Type your question here... / यहाँ अपना सवाल लिखें...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF050B24),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('$words / $kQueryMaxWords words (शब्द)',
                              style: TextStyle(color: words >= kQueryMaxWords ? Colors.orangeAccent : Colors.white54, fontSize: 12)),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: (_sending || words == 0) ? null : _send,
                            child: _sending
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Send / भेजें'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                child: Text(
                  'Doubts are deleted automatically after $kQueryRetentionDays days.\nडाउट $kQueryRetentionDays दिन बाद अपने आप डिलीट हो जाते हैं।',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 6, 2, 8),
                child: Text('My Queries / मेरे डाउट', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),

              // ---- my doubts ----
              if (snap.hasError)
                SizedBox(height: 220, child: ErrorView(error: snap.error))
              else if (!snap.hasData)
                const SizedBox(height: 120, child: LoadingView())
              else if (list.isEmpty)
                const SizedBox(height: 120, child: EmptyView('You have not sent any doubt yet.\nआपने अभी कोई डाउट नहीं भेजा है।'))
              else
                ...list.map(_queryCard),
            ],
          );
        },
      ),
    );
  }

  Widget _queryCard(QueryModel q) {
    final date = DateFormat('d MMM, h:mm a').format(q.when);
    return DepthCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(q.answered ? '✅ Replied / जवाब आया' : '⏳ Pending / लंबित',
                    style: TextStyle(color: q.answered ? Colors.greenAccent : Colors.amber, fontSize: 11.5, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(q.text, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
            if (q.answered) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFF29).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFFF29).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reply / जवाब', style: TextStyle(color: Color(0xFFFFFF29), fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(q.reply, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Deletes in ${q.daysLeft} days / ${q.daysLeft} दिन बाद डिलीट', style: const TextStyle(color: Colors.white30, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}
