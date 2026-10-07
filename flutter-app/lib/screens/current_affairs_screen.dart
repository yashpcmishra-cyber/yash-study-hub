import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/admin_session.dart';
import '../services/firestore_service.dart';
import '../utils/open_link.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';
import 'news_screen.dart';

const Color _gold = Color(0xFFFFFF29);
const Color _muted = Color(0xFF9AA3C7);
const Color _navy = Color(0xFF050B24);

/// C.Affairs tab: upar "Daily One-Liners" aur "News" ke beech badlav.
class CurrentAffairsScreen extends StatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  State<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen> {
  int _mode = 0;

  Widget _modeButton(int index, String label) {
    final on = _mode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? _gold : const Color(0x99081136),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(color: on ? _navy : Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current Affairs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Row(
              children: [
                _modeButton(0, 'Daily One-Liners'),
                const SizedBox(width: 8),
                _modeButton(1, 'News'),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _mode,
              children: const [
                DailyCaView(),
                NewsScreen(
                  categories: ['national', 'hindi_news', 'hindi_ca'],
                  title: 'Current Affairs',
                  showAppBar: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DailyCaView extends StatefulWidget {
  const DailyCaView({super.key});

  @override
  State<DailyCaView> createState() => _DailyCaViewState();
}

class _DailyCaViewState extends State<DailyCaView> {
  final _fs = FirestoreService();
  late final List<DateTime> _days;
  int _dayIndex = 0;
  String _topic = 'all';
  String _lang = 'both'; // both | hi | en
  late Stream<List<DailyCAModel>> _stream;
  bool _fallbackTried = false;
  String? _note;

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    // India ki date (IST = UTC+5:30), taaki script ki date se hamesha mile.
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    _days = List<DateTime>.generate(10, (i) => ist.subtract(Duration(days: i)));
    _stream = _fs.streamDailyCA(_keyOf(_days[0]));
  }

  static String _keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dayLabel(int i) {
    if (i == 0) return 'Today';
    if (i == 1) return 'Yesterday';
    final d = _days[i];
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
  }

  String _topicLabel(String key) {
    final pair = kDailyCaTopics[key] ?? kDailyCaTopics['misc']!;
    return _lang == 'hi' ? pair[1] : pair[0];
  }

  void _selectDay(int i, {bool auto = false}) {
    setState(() {
      _dayIndex = i;
      _topic = 'all';
      _note = auto ? 'Aaj ki lines abhi nahi aayi \u2014 ${_dayLabel(i)} ki dikha rahe hain' : null;
      _stream = _fs.streamDailyCA(_keyOf(_days[i]));
    });
  }

  // Aaj (Today) khaali ho to sabse taaza din (pichhle 3 din mein se) apne aap
  // dikha do, taaki subah-subah screen khaali na rahe. Sirf ek baar chalta hai.
  Future<void> _tryFallback() async {
    for (var i = 1; i < 4 && i < _days.length; i++) {
      try {
        final list = await _fs.streamDailyCA(_keyOf(_days[i])).first;
        if (!mounted) return;
        if (list.isNotEmpty) {
          _selectDay(i, auto: true);
          return;
        }
      } catch (_) {
        return;
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _stream = _fs.streamDailyCA(_keyOf(_days[_dayIndex])));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _confirmDelete(DailyCAModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this line?'),
        content: Text(item.en.isNotEmpty ? item.en : item.hi, maxLines: 4, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _fs.deleteDailyCA(item.date, item.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? _gold : const Color(0x99081136),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? _gold : const Color(0x33FFFFFF)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? _navy : Colors.white,
              fontSize: 12,
              fontWeight: on ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(DailyCAModel item) {
    final showEn = _lang != 'hi' && item.en.isNotEmpty;
    final showHi = _lang != 'en' && item.hi.isNotEmpty;
    return DepthCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _topicLabel(item.topic),
                    style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: adminSignedIn,
                  builder: (context, isAdmin, _) => isAdmin
                      ? InkWell(
                          onTap: () => _confirmDelete(item),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (showEn) Text(item.en, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
            if (showEn && showHi)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0x22FFFFFF)),
              ),
            if (showHi) Text(item.hi, style: const TextStyle(color: Color(0xFFDDE3FF), fontSize: 14, height: 1.5)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: item.link.isEmpty ? null : () => openExternalLink(context, item.link),
              child: Text(
                'Source: ${item.source}${item.link.isEmpty ? '' : '  \u203A'}',
                style: const TextStyle(color: _muted, fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _days.length,
            itemBuilder: (context, i) => _chip(_dayLabel(i), i == _dayIndex, () => _selectDay(i)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
          child: Row(
            children: [
              _chip('Both', _lang == 'both', () => setState(() => _lang = 'both')),
              _chip('\u0939\u093F\u0902\u0926\u0940', _lang == 'hi', () => setState(() => _lang = 'hi')),
              _chip('English', _lang == 'en', () => setState(() => _lang = 'en')),
            ],
          ),
        ),
        if (_note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(_note!, style: const TextStyle(color: _muted, fontSize: 11.5)),
          ),
        Expanded(
          child: StreamBuilder<List<DailyCAModel>>(
            stream: _stream,
            builder: (context, snap) {
              Widget content;
              if (snap.hasError) {
                content = PullableMessage(child: ErrorView(error: snap.error));
              } else if (!snap.hasData) {
                content = const PullableMessage(child: LoadingView());
              } else if (snap.data!.isEmpty) {
                if (_dayIndex == 0 && !_fallbackTried) {
                  _fallbackTried = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _tryFallback();
                  });
                }
                content = const PullableMessage(
                  child: EmptyView('Is din ke one-liners abhi nahi aaye \u2014 thodi der baad dekhein'),
                );
              } else {
                final items = snap.data!;
                final present = <String>{for (final i in items) i.topic};
                final sel = present.contains(_topic) ? _topic : 'all';
                final visible = sel == 'all' ? items : items.where((i) => i.topic == sel).toList();
                final topicKeys = kDailyCaTopics.keys.where(present.contains).toList();
                content = ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  itemCount: visible.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _chip('All', sel == 'all', () => setState(() => _topic = 'all')),
                              for (final k in topicKeys) _chip(_topicLabel(k), sel == k, () => setState(() => _topic = k)),
                            ],
                          ),
                        ),
                      );
                    }
                    return _card(visible[index - 1]);
                  },
                );
              }
              return RefreshIndicator(onRefresh: _refresh, child: content);
            },
          ),
        ),
      ],
    );
  }
}
