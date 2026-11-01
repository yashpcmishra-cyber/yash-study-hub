import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../app_colors.dart';
import '../services/mock_rank_service.dart';
import '../services/share_service.dart';
import '../services/study_store.dart';
import '../services/xp_store.dart';

/// Score card ka data (mock test ya quiz ka natija).
class ScoreShareData {
  final String title; // test / quiz ka naam
  final String big; // "42 / 50"
  final String bigLabel; // "Marks" / "Correct answers"
  final List<List<String>> stats; // [[label, value], ...] (max 3-4)
  const ScoreShareData({
    required this.title,
    required this.big,
    required this.bigLabel,
    this.stats = const <List<String>>[],
  });
}

/// "Score Card Share": natija ki ek sundar image banata hai (WhatsApp / Instagram status
/// ke liye) aur "Mujhe harao!" challenge ke saath share karta hai.
/// Is me Firestore ko kuch nahi chhua jaata. Message me sirf title aur app ka link jaata hai.
class ScoreShare {
  ScoreShare._();

  /// Preview sheet kholta hai. [rank] diya ho to card par rank bhi aata hai.
  static Future<void> open(BuildContext context, ScoreShareData data, {Future<MockRankInfo?>? rank}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _ShareSheet(data: data, rank: rank),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  final ScoreShareData data;
  final Future<MockRankInfo?>? rank;
  const _ShareSheet({required this.data, this.rank});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  String _rankText = '';
  String _streakText = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadExtras();
    widget.rank?.then((info) {
      if (!mounted || info == null) return;
      setState(() => _rankText = '🏆 Rank #${info.rank} of ${info.total}');
    }).catchError((_) {});
  }

  Future<void> _loadExtras() async {
    try {
      final s = await StudyStore.readStreak();
      final x = await XpStore.info();
      final parts = <String>[];
      if (s.days > 0) parts.add('🔥 ${s.days}-day streak');
      parts.add('⭐ Level ${x.level}');
      if (!mounted) return;
      setState(() => _streakText = parts.join('   •   '));
    } catch (_) {
      // card bina streak ke bhi theek hai
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final d = widget.data;
    final head = '🏆 I scored ${d.big} in ${d.title}!  / मैंने ${d.title} में ${d.big} स्कोर किया!';
    const line = 'Can you beat me? Download the Yash Study Hub app and try!\nक्या आप मुझे हरा सकते हैं? Yash Study Hub ऐप डाउनलोड करके देखिए!';
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('card not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('no image data');
      final file = File('${Directory.systemTemp.path}/score_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      await ShareService.customWithImage(context, head, line, file.path);
    } catch (_) {
      // Image na ban paye to bhi text ke saath share ho jaye.
      if (mounted) await ShareService.custom(context, head, line);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share your score / अपना स्कोर शेयर करें', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _Card(data: widget.data, rankText: _rankText, extraText: _streakText),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _share,
                icon: _busy
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.share),
                label: const Text('Share Score Card / स्कोर कार्ड शेयर करें'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asli card. Rang fix hain (Dark / Light theme se badalte nahi), taaki image hamesha ek jaisi bane.
class _Card extends StatelessWidget {
  final ScoreShareData data;
  final String rankText;
  final String extraText;
  const _Card({required this.data, required this.rankText, required this.extraText});

  static const Color _gold = Color(0xFFFFFF29);
  static const Color _navy = Color(0xFF081136);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081136), Color(0xFF1B2A7A)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  width: 30,
                  height: 30,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 30, height: 30),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Yash Study Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const Text('🎯', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFFF66), _gold]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(data.big, style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 44)),
                ),
                Text(data.bigLabel, style: const TextStyle(color: _navy, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (data.stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < data.stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(data.stats[i][1], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(data.stats[i][0], style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (rankText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(rankText, style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
          if (extraText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(extraText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ],
          const SizedBox(height: 16),
          const Text(
            'Can you beat me? 💪',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 2),
          const Text(
            'क्या आप मुझे हरा सकते हैं?',
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          const Text(
            '📲 Download Yash Study Hub',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
