// =============================================================================
//  Syllabus Tracker ka content (app ke andar hi bundled - internet / Firestore nahi).
//
//  Naya topic jodna ho: neeche kisi subject ki list me ek `SylTopic(...)` line
//  jodo. id UNIQUE rakho aur purani ids kabhi mat badlo (student ka progress
//  isi id se save hota hai). Ek hi topic id kai exams me aaye to progress share hota hai.
//  Naya exam jodna ho: kSylExams me ek `SylExam(...)` jodo.
//
//  Ye sirf aam (common) pattern hai - exam ki official notification dekhna zaroori hai.
// =============================================================================

class SylTopic {
  final String id;
  final String en;
  final String hi;
  const SylTopic(this.id, this.en, this.hi);
}

class SylSubject {
  final String id;
  final String emoji;
  final String en;
  final String hi;
  final List<SylTopic> topics;
  const SylSubject(this.id, this.emoji, this.en, this.hi, this.topics);
}

class SylExam {
  final String id;
  final String emoji;
  final String en;
  final String hi;
  final List<SylSubject> subjects;
  const SylExam(this.id, this.emoji, this.en, this.hi, this.subjects);

  int get totalTopics => subjects.fold<int>(0, (sum, s) => sum + s.topics.length);

  Iterable<SylTopic> get allTopics sync* {
    for (final s in subjects) {
      yield* s.topics;
    }
  }
}

// ------------------------------------------------------------ subjects

const SylSubject _quant = SylSubject('quant', '🔢', 'Quantitative Aptitude', 'गणित', [
  SylTopic('q.numsys', 'Number System', 'संख्या पद्धति'),
  SylTopic('q.hcflcm', 'HCF & LCM', 'म.स. और ल.स.'),
  SylTopic('q.simp', 'Simplification & BODMAS', 'सरलीकरण'),
  SylTopic('q.sqrt', 'Squares, Roots & Approximation', 'वर्ग, मूल और सन्निकटन'),
  SylTopic('q.series', 'Number Series', 'संख्या श्रेणी'),
  SylTopic('q.percent', 'Percentage', 'प्रतिशत'),
  SylTopic('q.ratio', 'Ratio & Proportion', 'अनुपात और समानुपात'),
  SylTopic('q.avg', 'Average', 'औसत'),
  SylTopic('q.pl', 'Profit, Loss & Discount', 'लाभ, हानि और छूट'),
  SylTopic('q.si', 'Simple & Compound Interest', 'साधारण व चक्रवृद्धि ब्याज'),
  SylTopic('q.tw', 'Time & Work', 'समय और कार्य'),
  SylTopic('q.tsd', 'Time, Speed & Distance', 'समय, चाल और दूरी'),
  SylTopic('q.mix', 'Mixture & Alligation', 'मिश्रण'),
  SylTopic('q.age', 'Ages', 'आयु संबंधी प्रश्न'),
  SylTopic('q.algebra', 'Algebra', 'बीजगणित'),
  SylTopic('q.geo', 'Geometry', 'ज्यामिति'),
  SylTopic('q.mens', 'Mensuration', 'क्षेत्रमिति'),
  SylTopic('q.trig', 'Trigonometry', 'त्रिकोणमिति'),
  SylTopic('q.di', 'Data Interpretation', 'आँकड़ा व्याख्या'),
]);

const SylSubject _reason = SylSubject('reason', '🧩', 'Reasoning', 'तर्कशक्ति', [
  SylTopic('r.analogy', 'Analogy', 'सादृश्यता'),
  SylTopic('r.classif', 'Classification (Odd one out)', 'वर्गीकरण'),
  SylTopic('r.series', 'Series (Letter / Number)', 'श्रृंखला'),
  SylTopic('r.coding', 'Coding-Decoding', 'कूट-लेखन'),
  SylTopic('r.blood', 'Blood Relations', 'रक्त संबंध'),
  SylTopic('r.direction', 'Direction Sense', 'दिशा ज्ञान'),
  SylTopic('r.rank', 'Ranking & Order', 'क्रम और रैंकिंग'),
  SylTopic('r.syll', 'Syllogism', 'न्याय निगमन'),
  SylTopic('r.venn', 'Venn Diagram', 'वेन आरेख'),
  SylTopic('r.puzzle', 'Seating Arrangement & Puzzles', 'बैठक व्यवस्था और पहेलियाँ'),
  SylTopic('r.ineq', 'Inequality', 'असमानता'),
  SylTopic('r.clock', 'Clock & Calendar', 'घड़ी और कैलेंडर'),
  SylTopic('r.math', 'Mathematical Operations', 'गणितीय संक्रियाएँ'),
  SylTopic('r.statement', 'Statement & Conclusion', 'कथन और निष्कर्ष'),
  SylTopic('r.nonverbal', 'Non-Verbal (Mirror, Paper Folding)', 'अशाब्दिक तर्क'),
]);

const SylSubject _english = SylSubject('english', '📖', 'English', 'अंग्रेज़ी', [
  SylTopic('e.grammar', 'Grammar Rules (Tenses, Articles, Prepositions)', 'व्याकरण के नियम'),
  SylTopic('e.spot', 'Error Spotting', 'त्रुटि पहचान'),
  SylTopic('e.fill', 'Fill in the Blanks', 'रिक्त स्थान भरना'),
  SylTopic('e.cloze', 'Cloze Test', 'क्लोज़ टेस्ट'),
  SylTopic('e.rc', 'Reading Comprehension', 'गद्यांश'),
  SylTopic('e.sent', 'Sentence Improvement', 'वाक्य सुधार'),
  SylTopic('e.para', 'Para Jumbles', 'पैरा जंबल'),
  SylTopic('e.vocab', 'Synonyms & Antonyms', 'पर्यायवाची और विलोम'),
  SylTopic('e.ow', 'One-Word Substitution', 'एक शब्द प्रतिस्थापन'),
  SylTopic('e.idiom', 'Idioms & Phrases', 'मुहावरे और वाक्यांश'),
  SylTopic('e.voice', 'Active-Passive & Narration', 'वाच्य और कथन'),
]);

const SylSubject _hindi = SylSubject('hindi', '📝', 'Hindi', 'हिंदी', [
  SylTopic('h.vyakaran', 'Sangya, Sarvanam, Visheshan, Kriya', 'संज्ञा, सर्वनाम, विशेषण, क्रिया'),
  SylTopic('h.sandhi', 'Sandhi', 'संधि'),
  SylTopic('h.samas', 'Samas', 'समास'),
  SylTopic('h.vilom', 'Paryayvachi & Vilom Shabd', 'पर्यायवाची और विलोम शब्द'),
  SylTopic('h.anek', 'Anek Shabdon ke liye Ek Shabd', 'अनेक शब्दों के लिए एक शब्द'),
  SylTopic('h.muhavare', 'Muhavare & Lokokti', 'मुहावरे और लोकोक्तियाँ'),
  SylTopic('h.ashuddhi', 'Shabd Shuddhi (Shuddh-Ashuddh)', 'शब्द शुद्धि'),
  SylTopic('h.ras', 'Ras, Chhand & Alankar', 'रस, छंद और अलंकार'),
  SylTopic('h.sahitya', 'Hindi Sahitya (Writers & Books)', 'हिंदी साहित्य'),
]);

const SylSubject _gs = SylSubject('gs', '🌍', 'General Studies', 'सामान्य अध्ययन', [
  SylTopic('g.history_anc', 'Ancient & Medieval History', 'प्राचीन व मध्यकालीन इतिहास'),
  SylTopic('g.history_mod', 'Modern History & Freedom Struggle', 'आधुनिक इतिहास व स्वतंत्रता संग्राम'),
  SylTopic('g.art', 'Art & Culture', 'कला एवं संस्कृति'),
  SylTopic('g.geo_ind', 'Indian Geography', 'भारतीय भूगोल'),
  SylTopic('g.geo_world', 'World Geography', 'विश्व भूगोल'),
  SylTopic('g.polity', 'Indian Polity & Constitution', 'भारतीय राजव्यवस्था व संविधान'),
  SylTopic('g.eco', 'Indian Economy', 'भारतीय अर्थव्यवस्था'),
  SylTopic('g.physics', 'Physics', 'भौतिक विज्ञान'),
  SylTopic('g.chem', 'Chemistry', 'रसायन विज्ञान'),
  SylTopic('g.bio', 'Biology', 'जीव विज्ञान'),
  SylTopic('g.env', 'Environment & Ecology', 'पर्यावरण व पारिस्थितिकी'),
  SylTopic('g.sci_tech', 'Science & Technology (Latest)', 'विज्ञान एवं प्रौद्योगिकी (नवीन)'),
  SylTopic('g.static', 'Static GK (Awards, Books, Sports)', 'स्थैतिक GK (पुरस्कार, पुस्तकें, खेल)'),
  SylTopic('g.ca', 'Current Affairs', 'समसामयिकी'),
]);

const SylSubject _computer = SylSubject('comp', '💻', 'Computer Awareness', 'कंप्यूटर ज्ञान', [
  SylTopic('c.basics', 'Computer Fundamentals', 'कंप्यूटर की मूल बातें'),
  SylTopic('c.hw', 'Hardware & Software', 'हार्डवेयर और सॉफ्टवेयर'),
  SylTopic('c.os', 'Operating Systems', 'ऑपरेटिंग सिस्टम'),
  SylTopic('c.office', 'MS Office (Word, Excel, PowerPoint)', 'एमएस ऑफिस'),
  SylTopic('c.net', 'Internet & Networking', 'इंटरनेट और नेटवर्किंग'),
  SylTopic('c.short', 'Keyboard Shortcuts', 'कीबोर्ड शॉर्टकट'),
  SylTopic('c.security', 'Cyber Security', 'साइबर सुरक्षा'),
]);

const SylSubject _bank = SylSubject('bank', '🏦', 'Banking Awareness', 'बैंकिंग जागरूकता', [
  SylTopic('b.rbi', 'RBI & Monetary Policy', 'आरबीआई और मौद्रिक नीति'),
  SylTopic('b.system', 'Banking System & Terms', 'बैंकिंग प्रणाली व शब्दावली'),
  SylTopic('b.fin', 'Financial Markets & Insurance', 'वित्तीय बाज़ार और बीमा'),
  SylTopic('b.schemes', 'Government Schemes', 'सरकारी योजनाएँ'),
  SylTopic('b.org', 'Important Organisations & HQs', 'महत्वपूर्ण संगठन व मुख्यालय'),
  SylTopic('b.budget', 'Budget & Economic Survey', 'बजट और आर्थिक सर्वेक्षण'),
]);

const SylSubject _up = SylSubject('up', '🏛️', 'Uttar Pradesh Special', 'उत्तर प्रदेश विशेष', [
  SylTopic('u.history', 'UP History & Culture', 'उत्तर प्रदेश का इतिहास व संस्कृति'),
  SylTopic('u.geo', 'UP Geography (Rivers, Districts, Soil)', 'उत्तर प्रदेश का भूगोल'),
  SylTopic('u.gk', 'UP GK (Fairs, Industries, Personalities)', 'उ.प्र. सामान्य ज्ञान'),
  SylTopic('u.govt', 'UP Government Schemes', 'उ.प्र. सरकार की योजनाएँ'),
  SylTopic('u.law', 'Criminal Laws (BNS, BNSS, BSA) Basics', 'आपराधिक कानून (BNS, BNSS, BSA) की मूल बातें'),
]);

// Kisi subject me se chune hue topics (exam ke hisaab se chhota syllabus).
SylSubject _pick(SylSubject s, List<String> ids) {
  return SylSubject(s.id, s.emoji, s.en, s.hi, s.topics.where((t) => ids.contains(t.id)).toList());
}

// --------------------------------------------------------------- exams

final List<SylExam> kSylExams = [
  SylExam('ssc', '🧾', 'SSC CGL / CHSL', 'एसएससी सीजीएल / सीएचएसएल', [
    _pick(_quant, [
      'q.numsys', 'q.hcflcm', 'q.simp', 'q.sqrt', 'q.percent', 'q.ratio', 'q.avg', 'q.pl', 'q.si', 'q.tw', 'q.tsd',
      'q.mix', 'q.age', 'q.algebra', 'q.geo', 'q.mens', 'q.trig', 'q.di',
    ]),
    _pick(_reason, [
      'r.analogy', 'r.classif', 'r.series', 'r.coding', 'r.blood', 'r.direction', 'r.rank', 'r.syll', 'r.venn',
      'r.clock', 'r.math', 'r.statement', 'r.nonverbal',
    ]),
    _english,
    _gs,
    _computer,
  ]),
  SylExam('bank', '🏦', 'Banking (IBPS / SBI PO-Clerk)', 'बैंकिंग (IBPS / SBI PO-क्लर्क)', [
    _pick(_quant, [
      'q.numsys', 'q.hcflcm', 'q.simp', 'q.sqrt', 'q.series', 'q.percent', 'q.ratio', 'q.avg', 'q.pl', 'q.si',
      'q.tw', 'q.tsd', 'q.mix', 'q.age', 'q.mens', 'q.di',
    ]),
    _pick(_reason, [
      'r.series', 'r.coding', 'r.blood', 'r.direction', 'r.rank', 'r.syll', 'r.puzzle', 'r.ineq', 'r.statement',
    ]),
    _pick(_english, ['e.grammar', 'e.spot', 'e.fill', 'e.cloze', 'e.rc', 'e.sent', 'e.para', 'e.vocab', 'e.idiom']),
    _bank,
    _computer,
    _pick(_gs, ['g.eco', 'g.ca', 'g.static']),
  ]),
  SylExam('rrb', '🚆', 'Railway (RRB NTPC / Group D)', 'रेलवे (RRB NTPC / ग्रुप D)', [
    _pick(_quant, [
      'q.numsys', 'q.hcflcm', 'q.simp', 'q.sqrt', 'q.percent', 'q.ratio', 'q.avg', 'q.pl', 'q.si', 'q.tw', 'q.tsd',
      'q.mix', 'q.age', 'q.algebra', 'q.geo', 'q.mens', 'q.trig',
    ]),
    _pick(_reason, [
      'r.analogy', 'r.classif', 'r.series', 'r.coding', 'r.blood', 'r.direction', 'r.rank', 'r.syll', 'r.venn',
      'r.clock', 'r.math', 'r.statement', 'r.nonverbal',
    ]),
    _gs,
  ]),
  SylExam('up', '👮', 'UP Police / UPSSSC PET', 'यूपी पुलिस / UPSSSC पेट', [
    _hindi,
    _pick(_quant, [
      'q.numsys', 'q.hcflcm', 'q.simp', 'q.percent', 'q.ratio', 'q.avg', 'q.pl', 'q.si', 'q.tw', 'q.tsd', 'q.age',
      'q.mens',
    ]),
    _pick(_reason, [
      'r.analogy', 'r.classif', 'r.series', 'r.coding', 'r.blood', 'r.direction', 'r.rank', 'r.syll', 'r.venn',
      'r.clock', 'r.math',
    ]),
    _gs,
    _up,
  ]),
];

SylExam? sylExamById(String id) {
  for (final e in kSylExams) {
    if (e.id == id) return e;
  }
  return null;
}
