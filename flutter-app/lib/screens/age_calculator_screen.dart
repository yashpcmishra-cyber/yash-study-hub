import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../data/important_days_data.dart';
import '../services/study_store.dart';

/// Age Calculator: janm tareekh se umar (saal-mahine-din) kisi bhi tareekh par,
/// agla janmdin, aur form bharne se pehle age-limit ki jaanch (category relaxation ke saath).
/// Kuch save nahi hota - Firestore ko 0 reads / 0 writes.
class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key});

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

/// Aam taur par milne wali chhoot (saal). Bharti ka official notification zaroor dekhein.
class _Cat {
  final String en;
  final String hi;
  final int relax;
  const _Cat(this.en, this.hi, this.relax);
}

const List<_Cat> _cats = [
  _Cat('General / UR', 'सामान्य', 0),
  _Cat('EWS', 'ईडब्ल्यूएस', 0),
  _Cat('OBC (NCL)', 'ओबीसी (एनसीएल)', 3),
  _Cat('SC / ST', 'एससी / एसटी', 5),
  _Cat('PwD (General)', 'दिव्यांग (सामान्य)', 10),
];

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime? _dob;
  late DateTime _asOn;
  bool _asOnIsToday = true;
  DateTime? _examDate;
  String _examName = '';
  int _cat = 0;
  final TextEditingController _minCtl = TextEditingController();
  final TextEditingController _maxCtl = TextEditingController();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _asOn = _today();
    _loadExam();
  }

  @override
  void dispose() {
    _minCtl.dispose();
    _maxCtl.dispose();
    super.dispose();
  }

  Future<void> _loadExam() async {
    try {
      final e = await StudyStore.readExam();
      if (!mounted) return;
      setState(() {
        _examDate = e.date;
        _examName = e.name;
      });
    } catch (_) {
      // exam chip nahi dikhega
    }
  }

  String _fmtDate(DateTime d) => '${d.day} ${kMonthShort[d.month - 1]} ${d.year}';

  static String _weekday(DateTime d) {
    const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return wd[d.weekday - 1];
  }

  Future<void> _pickDob() async {
    final now = _today();
    final init = _dob ?? DateTime(now.year - 22, 1, 1);
    final d = await showDatePicker(
      context: context,
      initialDate: init.isAfter(now) ? now : init,
      firstDate: DateTime(1940, 1, 1),
      lastDate: now,
      helpText: 'Date of birth / जन्म तिथि',
    );
    if (d != null && mounted) setState(() => _dob = DateTime(d.year, d.month, d.day));
  }

  Future<void> _pickAsOn() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _asOn,
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Age as on / इस तारीख को उम्र',
    );
    if (d != null && mounted) {
      setState(() {
        _asOn = DateTime(d.year, d.month, d.day);
        _asOnIsToday = _asOn == _today();
      });
    }
  }

  void _setAsOn(DateTime d) {
    setState(() {
      _asOn = DateTime(d.year, d.month, d.day);
      _asOnIsToday = _asOn == _today();
    });
  }

  // Do tareekhon ke beech ke din (UTC se, taaki time-zone / DST se gadbad na ho).
  static int _daysBetween(DateTime a, DateTime b) {
    final x = DateTime.utc(a.year, a.month, a.day);
    final y = DateTime.utc(b.year, b.month, b.day);
    return y.difference(x).inDays;
  }

  /// [asOn] par [dob] se umar: [saal, mahine, din].
  static List<int> _ymd(DateTime dob, DateTime asOn) {
    var y = asOn.year - dob.year;
    var m = asOn.month - dob.month;
    var d = asOn.day - dob.day;
    if (d < 0) {
      m--;
      d += DateTime(asOn.year, asOn.month, 0).day; // pichhle mahine ke din
    }
    if (m < 0) {
      y--;
      m += 12;
    }
    return [y, m, d];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Age Calculator / आयु कैलकुलेटर')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _dateTile('Date of birth / जन्म तिथि', _dob == null ? 'Tap to choose / चुनने के लिए टैप करें' : _fmtDate(_dob!), _pickDob, filled: _dob != null),
          const SizedBox(height: 10),
          _dateTile('Age as on / इस तारीख को उम्र', _asOnIsToday ? 'Today / आज  (${_fmtDate(_asOn)})' : _fmtDate(_asOn), _pickAsOn, filled: true),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Today / आज', _asOnIsToday, () => _setAsOn(_today())),
            if (_examDate != null) _chip('🎯 Exam date${_examName.isEmpty ? '' : ' ($_examName)'}', !_asOnIsToday && _asOn == _examDate, () => _setAsOn(_examDate!)),
            _chip('1 Jan ${_today().year}', _asOn == DateTime(_today().year, 1, 1), () => _setAsOn(DateTime(_today().year, 1, 1))),
            _chip('1 Jan ${_today().year + 1}', _asOn == DateTime(_today().year + 1, 1, 1), () => _setAsOn(DateTime(_today().year + 1, 1, 1))),
          ]),
          const SizedBox(height: 16),
          if (_dob == null)
            Text('Choose your date of birth to see your age.\nउम्र देखने के लिए जन्म तिथि चुनें।', textAlign: TextAlign.center, style: TextStyle(color: AppC.muted, fontSize: 12.5, height: 1.4))
          else if (_asOn.isBefore(_dob!))
            Text('"Age as on" date is before the date of birth.\n"इस तारीख को उम्र" जन्म तिथि से पहले की है।', textAlign: TextAlign.center, style: TextStyle(color: AppC.red, fontSize: 12.5, height: 1.4))
          else ...[
            _resultCard(_dob!),
            const SizedBox(height: 14),
            _eligibilitySection(_dob!),
          ],
        ],
      ),
    );
  }

  Widget _dateTile(String label, String value, VoidCallback onTap, {required bool filled}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppC.line)),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: AppC.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AppC.text54, fontSize: 11.5)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: filled ? AppC.text : AppC.text38, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_outlined, color: AppC.text54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppC.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? AppC.gold : AppC.text24),
        ),
        child: Text(label, style: TextStyle(color: active ? AppC.onGold : AppC.text, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }

  Widget _resultCard(DateTime dob) {
    final r = _ymd(dob, _asOn);
    final totalDays = _daysBetween(dob, _asOn);
    final totalMonths = r[0] * 12 + r[1];
    // Agla janmdin (asOn ke baad / usi din).
    var next = DateTime(_asOn.year, dob.month, dob.day);
    if (next.isBefore(_asOn)) next = DateTime(_asOn.year + 1, dob.month, dob.day);
    final toNext = _daysBetween(_asOn, next);
    final nextAge = next.year - dob.year;
    final birthdayLine = toNext == 0
        ? '🎂 Birthday today! / आज जन्मदिन है!'
        : '🎂 Next birthday (age $nextAge) in $toNext days / अगला जन्मदिन $toNext दिन बाद';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFF66), Color(0xFFFFFF29)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('${r[0]}', style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.bold, fontSize: 52)),
          const Text('years / वर्ष', style: TextStyle(color: AppC.onGold, fontSize: 13)),
          const SizedBox(height: 8),
          Text('${r[0]} years, ${r[1]} months, ${r[2]} days', textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${r[0]} वर्ष, ${r[1]} माह, ${r[2]} दिन', textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 13)),
          const SizedBox(height: 12),
          Text('= $totalMonths months  •  ${(totalDays / 7).floor()} weeks  •  $totalDays days', textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 12.5)),
          const SizedBox(height: 6),
          Text('Born on a ${_weekday(dob)} / जन्म ${_weekday(dob)} को', textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 12.5)),
          const SizedBox(height: 6),
          Text(birthdayLine, textAlign: TextAlign.center, style: const TextStyle(color: AppC.onGold, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _numField(String label, String hint, TextEditingController c) {
    return TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      keyboardType: TextInputType.number,
      style: TextStyle(color: AppC.text, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppC.text70, fontSize: 12.5),
        hintText: hint,
        hintStyle: TextStyle(color: AppC.text38, fontSize: 12.5),
        filled: true,
        fillColor: AppC.card,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _eligibilitySection(DateTime dob) {
    final minAge = int.tryParse(_minCtl.text.trim());
    final maxAge = int.tryParse(_maxCtl.text.trim());
    final cat = _cats[_cat];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Eligibility check / पात्रता जाँच', style: TextStyle(color: AppC.text, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text('Enter the age limit from the exam notification. / नोटिफिकेशन की आयु-सीमा भरें।', style: TextStyle(color: AppC.muted, fontSize: 11.5)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _numField('Min age / न्यूनतम', 'e.g. 18', _minCtl)),
          const SizedBox(width: 10),
          Expanded(child: _numField('Max age / अधिकतम', 'e.g. 27', _maxCtl)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < _cats.length; i++) _chip('${_cats[i].en}${_cats[i].relax > 0 ? '  +${_cats[i].relax}y' : ''}', _cat == i, () => setState(() => _cat = i)),
        ]),
        const SizedBox(height: 12),
        if (minAge == null && maxAge == null)
          Text('Fill Min and / or Max age to check.\nजाँच के लिए न्यूनतम / अधिकतम आयु भरें।', style: TextStyle(color: AppC.muted, fontSize: 12.5, height: 1.4))
        else
          _verdict(dob, minAge, maxAge, cat),
        const SizedBox(height: 12),
        Text(
          'Relaxation shown (OBC +3, SC/ST +5, PwD +10 years) is the common one. Many exams differ (e.g. ex-servicemen, state domicile), so always check the official notification.\n'
          'दिखाई गई छूट आम तौर पर मिलने वाली है। कई परीक्षाओं में अलग नियम होते हैं, इसलिए आधिकारिक नोटिफिकेशन ज़रूर देखें।',
          style: TextStyle(color: AppC.muted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _verdict(DateTime dob, int? minAge, int? maxAge, _Cat cat) {
    final years = _ymd(dob, _asOn)[0];
    final allowedMax = maxAge == null ? null : maxAge + cat.relax;
    final tooYoung = minAge != null && years < minAge;
    final tooOld = allowedMax != null && years > allowedMax;
    final ok = !tooYoung && !tooOld;

    final lines = <String>[];
    lines.add('Your age on ${_fmtDate(_asOn)}: $years years / आपकी उम्र: $years वर्ष');
    if (minAge != null) {
      lines.add('Minimum: $minAge years ${tooYoung ? '✗' : '✓'}');
    }
    if (allowedMax != null) {
      final relaxNote = cat.relax > 0 ? ' ($maxAge + ${cat.relax} relaxation)' : '';
      lines.add('Maximum: $allowedMax years$relaxNote ${tooOld ? '✗' : '✓'}');
      // Sabse purani janm tareekh jo abhi bhi eligible hai: upper-limit + 1 saal poore na hue ho.
      final earliest = DateTime(_asOn.year - (allowedMax + 1), _asOn.month, _asOn.day).add(const Duration(days: 1));
      lines.add('Earliest eligible date of birth: ${_fmtDate(earliest)} / सबसे पुरानी पात्र जन्म तिथि');
    }
    if (minAge != null) {
      final latest = DateTime(_asOn.year - minAge, _asOn.month, _asOn.day);
      lines.add('Latest eligible date of birth: ${_fmtDate(latest)} / सबसे नई पात्र जन्म तिथि');
    }

    final String headline;
    if (ok) {
      headline = '✅ Age is within the limit / उम्र सीमा के अंदर है';
    } else if (tooYoung) {
      headline = '❌ Too young by ${minAge! - years} year(s) / उम्र कम है';
    } else {
      headline = '❌ Over the limit by ${years - allowedMax!} year(s) / उम्र ज़्यादा है';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? AppC.greenWash : AppC.redWash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? AppC.green : AppC.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: TextStyle(color: ok ? AppC.green : AppC.red, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l, style: TextStyle(color: AppC.text, fontSize: 12.5, height: 1.35)),
            ),
        ],
      ),
    );
  }
}
