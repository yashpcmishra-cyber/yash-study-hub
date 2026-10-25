// =============================================================================
//  Flashcards ka content (app ke andar hi bundled - internet / Firestore nahi).
//  Naya card jodna ho to kisi bhi category ke end me ek line add kar do,
//  id unique rakho (jaise 'p15'). Purani ids kabhi mat badlo.
// =============================================================================

class Flashcard {
  final String id;
  final String cat;
  final String q; // question (English)
  final String qh; // question (Hindi)
  final String a; // answer (English)
  final String ah; // answer (Hindi)
  const Flashcard(this.id, this.cat, this.q, this.qh, this.a, this.ah);
}

/// category key -> [English naam, Hindi naam, emoji]
const Map<String, List<String>> kFlashCats = {
  'polity': ['Polity', 'राजव्यवस्था', '🏛️'],
  'geo': ['Geography', 'भूगोल', '🌏'],
  'history': ['History', 'इतिहास', '📜'],
  'science': ['Science', 'विज्ञान', '🔬'],
  'economy': ['Economy', 'अर्थव्यवस्था', '💰'],
  'maths': ['Maths Formulas', 'गणित सूत्र', '➗'],
  'english': ['One-Word / English', 'एक शब्द / अंग्रेज़ी', '📖'],
};

const List<Flashcard> kFlashcards = [
  // ------------------------------------------------------------ POLITY
  Flashcard('p01', 'polity', "Who is called the 'Father of the Indian Constitution'?", "भारतीय संविधान का जनक किसे कहा जाता है?", "Dr. B. R. Ambedkar (Chairman of the Drafting Committee).", "डॉ. बी. आर. आंबेडकर (प्रारूप समिति के अध्यक्ष)।"),
  Flashcard('p02', 'polity', "When did the Constitution of India come into effect?", "भारत का संविधान कब लागू हुआ?", "26 January 1950 (it was adopted on 26 November 1949).", "26 जनवरी 1950 (इसे 26 नवंबर 1949 को अपनाया गया था)।"),
  Flashcard('p03', 'polity', "Article 14 deals with?", "अनुच्छेद 14 किससे संबंधित है?", "Equality before law and equal protection of the laws.", "विधि के समक्ष समानता और कानूनों का समान संरक्षण।"),
  Flashcard('p04', 'polity', "Article 21 guarantees?", "अनुच्छेद 21 क्या गारंटी देता है?", "Right to life and personal liberty.", "प्राण और दैहिक स्वतंत्रता का अधिकार।"),
  Flashcard('p05', 'polity', "Article 21A and which amendment added it?", "अनुच्छेद 21A क्या है और किस संशोधन से जुड़ा?", "Right to free and compulsory education for ages 6-14; 86th Amendment (2002).", "6-14 वर्ष के बच्चों को निःशुल्क व अनिवार्य शिक्षा; 86वाँ संशोधन (2002)।"),
  Flashcard('p06', 'polity', "Which Article is the 'Right to Constitutional Remedies'?", "संवैधानिक उपचारों का अधिकार कौन-सा अनुच्छेद है?", "Article 32 (Dr. Ambedkar called it the heart and soul of the Constitution).", "अनुच्छेद 32 (डॉ. आंबेडकर ने इसे संविधान की आत्मा कहा)।"),
  Flashcard('p07', 'polity', "Fundamental Duties were added by which amendment?", "मौलिक कर्तव्य किस संशोधन से जोड़े गए?", "42nd Amendment (1976), Part IVA, Article 51A.", "42वाँ संशोधन (1976), भाग IVA, अनुच्छेद 51A।"),
  Flashcard('p08', 'polity', "Minimum age: President / Rajya Sabha / Lok Sabha member?", "न्यूनतम आयु: राष्ट्रपति / राज्यसभा / लोकसभा सदस्य?", "President 35 years, Rajya Sabha 30 years, Lok Sabha 25 years.", "राष्ट्रपति 35 वर्ष, राज्यसभा 30 वर्ष, लोकसभा 25 वर्ष।"),
  Flashcard('p09', 'polity', "Name the five writs.", "पाँच रिट (लेख) के नाम बताइए।", "Habeas Corpus, Mandamus, Prohibition, Certiorari, Quo Warranto.", "बंदी प्रत्यक्षीकरण, परमादेश, प्रतिषेध, उत्प्रेषण, अधिकार पृच्छा।"),
  Flashcard('p10', 'polity', "Which amendment gave constitutional status to Panchayati Raj?", "पंचायती राज को संवैधानिक दर्जा किस संशोधन से मिला?", "73rd Amendment (1992). Urban local bodies: 74th Amendment.", "73वाँ संशोधन (1992)। नगर निकाय: 74वाँ संशोधन।"),
  Flashcard('p11', 'polity', "The Anti-Defection Law is in which Schedule?", "दल-बदल विरोधी कानून किस अनुसूची में है?", "10th Schedule (added by the 52nd Amendment, 1985).", "10वीं अनुसूची (52वें संशोधन, 1985 से जुड़ी)।"),
  Flashcard('p12', 'polity', "How many Fundamental Rights are there now? Which right was removed?", "अब कितने मौलिक अधिकार हैं? कौन-सा अधिकार हटा?", "Six. Right to Property was removed by the 44th Amendment (1978); it is now a legal right under Article 300A.", "छह। संपत्ति का अधिकार 44वें संशोधन (1978) से हटा; अब अनुच्छेद 300A में कानूनी अधिकार है।"),
  Flashcard('p13', 'polity', "Which case gave the 'Basic Structure' doctrine?", "'मूल ढाँचा' सिद्धांत किस केस से आया?", "Kesavananda Bharati case (1973).", "केशवानंद भारती केस (1973)।"),
  Flashcard('p14', 'polity', "Article 324 and Article 148 deal with?", "अनुच्छेद 324 और 148 किससे संबंधित हैं?", "Article 324: Election Commission. Article 148: Comptroller and Auditor General (CAG).", "अनुच्छेद 324: निर्वाचन आयोग। अनुच्छेद 148: नियंत्रक एवं महालेखा परीक्षक (CAG)।"),

  // --------------------------------------------------------- GEOGRAPHY
  Flashcard('g01', 'geo', "Largest and smallest Indian state by area?", "क्षेत्रफल में सबसे बड़ा और सबसे छोटा राज्य?", "Largest: Rajasthan. Smallest: Goa.", "सबसे बड़ा: राजस्थान। सबसे छोटा: गोवा।"),
  Flashcard('g02', 'geo', "Longest river within India?", "भारत के भीतर सबसे लंबी नदी?", "Ganga (about 2,525 km).", "गंगा (लगभग 2,525 किमी)।"),
  Flashcard('g03', 'geo', "Highest peak of India (within Indian territory)?", "भारतीय क्षेत्र की सबसे ऊँची चोटी?", "Kangchenjunga (8,586 m), the third highest in the world.", "कंचनजंगा (8,586 मी), विश्व की तीसरी सबसे ऊँची चोटी।"),
  Flashcard('g04', 'geo', "How many Indian states does the Tropic of Cancer pass through?", "कर्क रेखा भारत के कितने राज्यों से गुज़रती है?", "Eight: Gujarat, Rajasthan, Madhya Pradesh, Chhattisgarh, Jharkhand, West Bengal, Tripura, Mizoram.", "आठ: गुजरात, राजस्थान, मध्य प्रदेश, छत्तीसगढ़, झारखंड, पश्चिम बंगाल, त्रिपुरा, मिज़ोरम।"),
  Flashcard('g05', 'geo', "Standard Meridian of India?", "भारत की मानक याम्योत्तर रेखा?", "82°30′ E, passing near Mirzapur (Uttar Pradesh). IST = UTC + 5:30.", "82°30′ पूर्व, मिर्ज़ापुर (उत्तर प्रदेश) के पास से। IST = UTC + 5:30।"),
  Flashcard('g06', 'geo', "Largest brackish-water lagoon in India?", "भारत की सबसे बड़ी खारे पानी की लैगून झील?", "Chilika Lake (Odisha).", "चिल्का झील (ओडिशा)।"),
  Flashcard('g07', 'geo', "Which two big rivers flow west into the Arabian Sea through rift valleys?", "कौन-सी दो बड़ी नदियाँ दरार घाटियों से पश्चिम में अरब सागर में गिरती हैं?", "Narmada and Tapi.", "नर्मदा और तापी।"),
  Flashcard('g08', 'geo', "'Dakshin Ganga' is the name of which river?", "'दक्षिण गंगा' किस नदी को कहते हैं?", "Godavari.", "गोदावरी।"),
  Flashcard('g09', 'geo', "Highest peak of the Western Ghats?", "पश्चिमी घाट की सबसे ऊँची चोटी?", "Anamudi (2,695 m), Kerala.", "अनामुडी (2,695 मी), केरल।"),
  Flashcard('g10', 'geo', "Which soil is best for cotton? Another name?", "कपास के लिए सबसे अच्छी मिट्टी? दूसरा नाम?", "Black soil, also called Regur.", "काली मिट्टी, जिसे रेगुर भी कहते हैं।"),
  Flashcard('g11', 'geo', "Wettest place in India (Meghalaya)?", "भारत का सबसे अधिक वर्षा वाला स्थान (मेघालय)?", "Mawsynram (Cherrapunji is nearby).", "मौसिनराम (चेरापूंजी पास में है)।"),
  Flashcard('g12', 'geo', "How many land neighbours does India have?", "भारत के कितने स्थलीय पड़ोसी देश हैं?", "Seven: Pakistan, Afghanistan, China, Nepal, Bhutan, Bangladesh, Myanmar.", "सात: पाकिस्तान, अफ़गानिस्तान, चीन, नेपाल, भूटान, बांग्लादेश, म्यांमार।"),
  Flashcard('g13', 'geo', "Southernmost point of India?", "भारत का सबसे दक्षिणी बिंदु?", "Indira Point (Great Nicobar Island).", "इंदिरा पॉइंट (ग्रेट निकोबार द्वीप)।"),
  Flashcard('g14', 'geo', "Oldest fold mountain range of India vs the youngest?", "भारत की सबसे पुरानी और सबसे नई वलित पर्वतमाला?", "Oldest: Aravalli. Youngest: Himalaya.", "सबसे पुरानी: अरावली। सबसे नई: हिमालय।"),

  // ----------------------------------------------------------- HISTORY
  Flashcard('h01', 'history', "Battle of Plassey and Battle of Buxar - years?", "प्लासी और बक्सर के युद्ध - वर्ष?", "Plassey: 1757. Buxar: 1764.", "प्लासी: 1757। बक्सर: 1764।"),
  Flashcard('h02', 'history', "Where and when did the Revolt of 1857 begin?", "1857 की क्रांति कहाँ और कब शुरू हुई?", "Meerut, 10 May 1857.", "मेरठ, 10 मई 1857।"),
  Flashcard('h03', 'history', "Jallianwala Bagh massacre - date, place, officer?", "जलियाँवाला बाग हत्याकांड - तारीख, स्थान, अधिकारी?", "13 April 1919, Amritsar; General Dyer.", "13 अप्रैल 1919, अमृतसर; जनरल डायर।"),
  Flashcard('h04', 'history', "Why was the Non-Cooperation Movement withdrawn?", "असहयोग आंदोलन क्यों वापस लिया गया?", "After the Chauri Chaura incident (1922).", "चौरी-चौरा कांड (1922) के बाद।"),
  Flashcard('h05', 'history', "Dandi March - date and purpose?", "दांडी मार्च - तारीख और उद्देश्य?", "12 March 1930; Salt Satyagraha against the salt law (Civil Disobedience Movement).", "12 मार्च 1930; नमक कानून के विरोध में नमक सत्याग्रह (सविनय अवज्ञा आंदोलन)।"),
  Flashcard('h06', 'history', "Quit India Movement - date and slogan?", "भारत छोड़ो आंदोलन - तारीख और नारा?", "8 August 1942; 'Do or Die'.", "8 अगस्त 1942; 'करो या मरो'।"),
  Flashcard('h07', 'history', "Who founded the Indian National Congress and when? First president?", "भारतीय राष्ट्रीय कांग्रेस की स्थापना किसने और कब की? पहले अध्यक्ष?", "A. O. Hume, 1885. First president: W. C. Bonnerjee.", "ए. ओ. ह्यूम, 1885। पहले अध्यक्ष: डब्ल्यू. सी. बनर्जी।"),
  Flashcard('h08', 'history', "Who partitioned Bengal and when?", "बंगाल का विभाजन किसने और कब किया?", "Lord Curzon, 1905.", "लॉर्ड कर्ज़न, 1905।"),
  Flashcard('h09', 'history', "First Battle of Panipat - year and winner?", "पानीपत का पहला युद्ध - वर्ष और विजेता?", "1526; Babur defeated Ibrahim Lodi.", "1526; बाबर ने इब्राहीम लोदी को हराया।"),
  Flashcard('h10', 'history', "Battle of Haldighati - year and fighters?", "हल्दीघाटी का युद्ध - वर्ष और योद्धा?", "1576; Akbar's army (Man Singh) vs Maharana Pratap.", "1576; अकबर की सेना (मान सिंह) बनाम महाराणा प्रताप।"),
  Flashcard('h11', 'history', "Which war made Ashoka turn to Buddhism?", "किस युद्ध के बाद अशोक ने बौद्ध धर्म अपनाया?", "The Kalinga War (about 261 BCE).", "कलिंग युद्ध (लगभग 261 ईसा पूर्व)।"),
  Flashcard('h12', 'history', "Which period is called the 'Golden Age' of ancient India?", "प्राचीन भारत का 'स्वर्ण युग' किस काल को कहते हैं?", "The Gupta period.", "गुप्त काल।"),
  Flashcard('h13', 'history', "Famous structure of Mohenjo-daro?", "मोहनजोदड़ो की प्रसिद्ध संरचना?", "The Great Bath.", "विशाल स्नानागार (ग्रेट बाथ)।"),
  Flashcard('h14', 'history', "First President of India and first PM of India?", "भारत के पहले राष्ट्रपति और पहले प्रधानमंत्री?", "President: Dr. Rajendra Prasad. PM: Jawaharlal Nehru.", "राष्ट्रपति: डॉ. राजेंद्र प्रसाद। प्रधानमंत्री: जवाहरलाल नेहरू।"),

  // ----------------------------------------------------------- SCIENCE
  Flashcard('s01', 'science', "SI units of force, energy, power, pressure?", "बल, ऊर्जा, शक्ति, दाब की SI इकाइयाँ?", "Force: Newton. Energy/Work: Joule. Power: Watt. Pressure: Pascal.", "बल: न्यूटन। ऊर्जा/कार्य: जूल। शक्ति: वाट। दाब: पास्कल।"),
  Flashcard('s02', 'science', "Speed of light in vacuum?", "निर्वात में प्रकाश की चाल?", "About 3 × 10⁸ m/s (3,00,000 km/s).", "लगभग 3 × 10⁸ मी/से (3,00,000 किमी/से)।"),
  Flashcard('s03', 'science', "Diseases from deficiency of Vitamin A, B1, C, D?", "विटामिन A, B1, C, D की कमी से रोग?", "A: Night blindness. B1: Beriberi. C: Scurvy. D: Rickets.", "A: रतौंधी। B1: बेरीबेरी। C: स्कर्वी। D: रिकेट्स।"),
  Flashcard('s04', 'science', "Powerhouse of the cell?", "कोशिका का ऊर्जा-घर?", "Mitochondria.", "माइटोकॉन्ड्रिया।"),
  Flashcard('s05', 'science', "Number of bones in an adult human body? Largest and smallest bone?", "वयस्क शरीर में हड्डियाँ? सबसे बड़ी और सबसे छोटी हड्डी?", "206. Largest: femur (thigh). Smallest: stapes (ear).", "206। सबसे बड़ी: फीमर (जाँघ)। सबसे छोटी: स्टेपीज़ (कान)।"),
  Flashcard('s06', 'science', "Largest organ and largest gland of the human body?", "मानव शरीर का सबसे बड़ा अंग और सबसे बड़ी ग्रंथि?", "Largest organ: skin. Largest gland: liver.", "सबसे बड़ा अंग: त्वचा। सबसे बड़ी ग्रंथि: यकृत (लिवर)।"),
  Flashcard('s07', 'science', "pH of pure water? Acid and base range?", "शुद्ध जल का pH? अम्ल और क्षार की सीमा?", "7 (neutral). Below 7 acidic, above 7 basic.", "7 (उदासीन)। 7 से कम अम्लीय, 7 से अधिक क्षारीय।"),
  Flashcard('s08', 'science', "Chemical formulas: common salt, baking soda, bleaching powder?", "रासायनिक सूत्र: नमक, खाने का सोडा, ब्लीचिंग पाउडर?", "NaCl, NaHCO₃, CaOCl₂.", "NaCl, NaHCO₃, CaOCl₂।"),
  Flashcard('s09', 'science', "Chemical name of Plaster of Paris?", "प्लास्टर ऑफ पेरिस का रासायनिक नाम?", "Calcium sulphate hemihydrate (CaSO₄·½H₂O).", "कैल्शियम सल्फेट हेमिहाइड्रेट (CaSO₄·½H₂O)।"),
  Flashcard('s10', 'science', "Ohm's law?", "ओम का नियम?", "V = I × R (voltage = current × resistance).", "V = I × R (वोल्टेज = धारा × प्रतिरोध)।"),
  Flashcard('s11', 'science', "Most abundant gas in the atmosphere? Lightest gas?", "वायुमंडल में सबसे अधिक गैस? सबसे हल्की गैस?", "Most abundant: Nitrogen (about 78%). Lightest: Hydrogen.", "सबसे अधिक: नाइट्रोजन (लगभग 78%)। सबसे हल्की: हाइड्रोजन।"),
  Flashcard('s12', 'science', "Deficiency diseases: iron, iodine, calcium?", "कमी से रोग: आयरन, आयोडीन, कैल्शियम?", "Iron: Anaemia. Iodine: Goitre. Calcium: weak bones / Osteoporosis.", "आयरन: एनीमिया। आयोडीन: घेंघा। कैल्शियम: कमज़ोर हड्डियाँ / ऑस्टियोपोरोसिस।"),
  Flashcard('s13', 'science', "Hardest natural substance?", "सबसे कठोर प्राकृतिक पदार्थ?", "Diamond.", "हीरा।"),
  Flashcard('s14', 'science', "Normal human body temperature?", "मानव शरीर का सामान्य तापमान?", "37 °C (98.6 °F).", "37 °C (98.6 °F)।"),

  // ----------------------------------------------------------- ECONOMY
  Flashcard('e01', 'economy', "When was RBI established? Where is its headquarters?", "RBI की स्थापना कब हुई? मुख्यालय कहाँ है?", "1 April 1935; headquarters in Mumbai (nationalised in 1949).", "1 अप्रैल 1935; मुख्यालय मुंबई (1949 में राष्ट्रीयकृत)।"),
  Flashcard('e02', 'economy', "What is the Repo Rate?", "रेपो रेट क्या है?", "The rate at which RBI lends short-term money to commercial banks.", "वह दर जिस पर RBI वाणिज्यिक बैंकों को अल्पकालिक ऋण देता है।"),
  Flashcard('e03', 'economy', "When was GST implemented in India?", "भारत में GST कब लागू हुआ?", "1 July 2017.", "1 जुलाई 2017।"),
  Flashcard('e04', 'economy', "NITI Aayog replaced which body and when?", "नीति आयोग ने किसकी जगह ली और कब?", "Planning Commission; 1 January 2015.", "योजना आयोग; 1 जनवरी 2015।"),
  Flashcard('e05', 'economy', "Financial year in India?", "भारत में वित्तीय वर्ष?", "1 April to 31 March.", "1 अप्रैल से 31 मार्च।"),
  Flashcard('e06', 'economy', "First Five Year Plan - period?", "पहली पंचवर्षीय योजना - अवधि?", "1951-56.", "1951-56।"),
  Flashcard('e07', 'economy', "Who is the 'Father of the White Revolution' (Operation Flood)?", "श्वेत क्रांति (ऑपरेशन फ्लड) के जनक?", "Dr. Verghese Kurien.", "डॉ. वर्गीज़ कुरियन।"),
  Flashcard('e08', 'economy', "Which Article deals with the Annual Financial Statement (Budget)?", "वार्षिक वित्तीय विवरण (बजट) किस अनुच्छेद में है?", "Article 112.", "अनुच्छेद 112।"),

  // ------------------------------------------------------------- MATHS
  Flashcard('m01', 'maths', "Area and circumference of a circle?", "वृत्त का क्षेत्रफल और परिधि?", "Area = πr². Circumference = 2πr.", "क्षेत्रफल = πr²। परिधि = 2πr।"),
  Flashcard('m02', 'maths', "Area of a triangle (two formulas)?", "त्रिभुज का क्षेत्रफल (दो सूत्र)?", "½ × base × height. Heron: √[s(s−a)(s−b)(s−c)], s = (a+b+c)/2.", "½ × आधार × ऊँचाई। हेरोन: √[s(s−a)(s−b)(s−c)], s = (a+b+c)/2।"),
  Flashcard('m03', 'maths', "Volume and curved surface area of a cylinder?", "बेलन का आयतन और वक्र पृष्ठ क्षेत्रफल?", "Volume = πr²h. CSA = 2πrh.", "आयतन = πr²h। वक्र पृष्ठ = 2πrh।"),
  Flashcard('m04', 'maths', "Volume and surface area of a sphere?", "गोले का आयतन और पृष्ठ क्षेत्रफल?", "Volume = 4/3 πr³. Surface area = 4πr².", "आयतन = 4/3 πr³। पृष्ठ क्षेत्रफल = 4πr²।"),
  Flashcard('m05', 'maths', "Volume of a cone?", "शंकु का आयतन?", "1/3 × πr²h.", "1/3 × πr²h।"),
  Flashcard('m06', 'maths', "(a + b)² and a² − b²?", "(a + b)² और a² − b²?", "(a+b)² = a² + 2ab + b². a² − b² = (a+b)(a−b).", "(a+b)² = a² + 2ab + b²। a² − b² = (a+b)(a−b)।"),
  Flashcard('m07', 'maths', "Simple Interest and Compound Amount?", "साधारण ब्याज और चक्रवृद्धि मिश्रधन?", "SI = (P × R × T)/100. Amount = P(1 + R/100)ⁿ.", "SI = (P × R × T)/100। मिश्रधन = P(1 + R/100)ⁿ।"),
  Flashcard('m08', 'maths', "Convert km/h to m/s? Average speed for equal distances at speeds x and y?", "किमी/घंटा से मी/से? बराबर दूरी पर चाल x और y हो तो औसत चाल?", "Multiply by 5/18. Average speed = 2xy/(x+y).", "5/18 से गुणा करें। औसत चाल = 2xy/(x+y)।"),
  Flashcard('m09', 'maths', "Profit % and selling price formula?", "लाभ % और विक्रय मूल्य का सूत्र?", "Profit % = (Profit/CP) × 100. SP = CP × (100 + P%)/100.", "लाभ % = (लाभ/क्रय मूल्य) × 100। SP = CP × (100 + P%)/100।"),
  Flashcard('m10', 'maths', "Sum of first n natural numbers and of their squares?", "पहली n प्राकृत संख्याओं का योग और उनके वर्गों का योग?", "n(n+1)/2 and n(n+1)(2n+1)/6.", "n(n+1)/2 और n(n+1)(2n+1)/6।"),
  Flashcard('m11', 'maths', "Roots of ax² + bx + c = 0?", "ax² + bx + c = 0 के मूल?", "x = [−b ± √(b² − 4ac)] / 2a.", "x = [−b ± √(b² − 4ac)] / 2a।"),
  Flashcard('m12', 'maths', "nth term and sum of an AP?", "AP का nवाँ पद और योग?", "aₙ = a + (n−1)d. Sₙ = n/2 × [2a + (n−1)d].", "aₙ = a + (n−1)d। Sₙ = n/2 × [2a + (n−1)d]।"),

  // --------------------------------------------------------- ENGLISH
  Flashcard('n01', 'english', "One word: 'One who knows everything'", "एक शब्द: 'जो सब कुछ जानता हो'", "Omniscient.", "सर्वज्ञ (Omniscient)।"),
  Flashcard('n02', 'english', "One word: 'Study of birds'", "एक शब्द: 'पक्षियों का अध्ययन'", "Ornithology.", "पक्षी विज्ञान (Ornithology)।"),
  Flashcard('n03', 'english', "One word: 'Fear of heights'", "एक शब्द: 'ऊँचाई से डर'", "Acrophobia.", "एक्रोफोबिया (Acrophobia)।"),
  Flashcard('n04', 'english', "One word: 'A person who loves books'", "एक शब्द: 'किताबों से प्यार करने वाला'", "Bibliophile.", "पुस्तक-प्रेमी (Bibliophile)।"),
  Flashcard('n05', 'english', "One word: 'A medicine that cures all diseases'", "एक शब्द: 'सब रोगों की दवा'", "Panacea.", "रामबाण (Panacea)।"),
  Flashcard('n06', 'english', "One word: 'Speaking in one's sleep'", "एक शब्द: 'नींद में बोलना'", "Somniloquy.", "नींद में बड़बड़ाना (Somniloquy)।"),
  Flashcard('n07', 'english', "One word: 'Killing of one's own brother'", "एक शब्द: 'अपने भाई की हत्या'", "Fratricide.", "भ्रातृहत्या (Fratricide)।"),
  Flashcard('n08', 'english', "One word: 'A government by the rich'", "एक शब्द: 'अमीरों का शासन'", "Plutocracy.", "धनिकतंत्र (Plutocracy)।"),
];
