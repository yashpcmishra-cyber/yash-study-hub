// =============================================================================
//  "Aaj ka Gyaan" ka content: Word of the Day + ek GK fact.
//  Roz date ke hisaab se ek-ek entry badalti hai (words aur facts alag-alag
//  cycle mein chalte hain, isliye jodi roz nayi banti hai).
//  App ke andar bundled hai - internet / Firestore ki zaroorat nahi.
//
//  WORD OF THE DAY : Banking PO (IBPS PO / SBI PO) English section ke level ke
//                    vocabulary words (Hindu-editorial / RC / synonyms-antonyms).
//  DID YOU KNOW    : Hard-level facts - General Science, General Studies
//                    (Polity / History / Economy / Geography) aur Static GK,
//                    UP ke topics ke saath - SSC CGL, RRB NTPC, UPSSSC,
//                    AHC RO aur UPPSC ke syllabus ke hisaab se.
//
//  Naya word / fact jodna ho: neeche ki list mein ek line aur jodo.
// =============================================================================

class GyanWord {
  final String word;
  final String hi; // Hindi meaning
  final String en; // English meaning
  final String example;
  const GyanWord(this.word, this.hi, this.en, this.example);
}

class GyanFact {
  final String en;
  final String hi;
  const GyanFact(this.en, this.hi);
}

// Banking PO level vocabulary (68 words)
const List<GyanWord> kGyanWords = [
  GyanWord('Ameliorate', 'सुधारना / बेहतर बनाना', 'To make a bad situation better', 'The new policy aims to ameliorate the condition of small farmers.'),
  GyanWord('Obfuscate', 'उलझाना / धुंधला करना', 'To make something unclear or confusing', 'The report tried to obfuscate the real losses.'),
  GyanWord('Pernicious', 'हानिकारक / घातक', 'Causing harm in a gradual, subtle way', 'Misinformation has a pernicious effect on society.'),
  GyanWord('Ephemeral', 'क्षणभंगुर', 'Lasting for a very short time', 'Fame in the film world is often ephemeral.'),
  GyanWord('Capricious', 'सनकी / मनमौजी', 'Given to sudden changes of mood or behaviour', 'The capricious weather ruined the plan.'),
  GyanWord('Equivocal', 'दुविधापूर्ण / अस्पष्ट', 'Open to more than one interpretation', 'The minister gave an equivocal reply.'),
  GyanWord('Sycophant', 'चापलूस', 'A person who flatters the powerful to gain favour', 'The boss was surrounded by sycophants.'),
  GyanWord('Recalcitrant', 'अड़ियल / अवज्ञाकारी', 'Stubbornly resisting authority or control', 'The recalcitrant borrower ignored every notice.'),
  GyanWord('Magnanimous', 'उदारचित्त', 'Generous and forgiving, especially towards a rival', 'He was magnanimous in victory.'),
  GyanWord('Taciturn', 'मितभाषी / चुप्पा', 'Reserved; saying very little', 'The taciturn clerk rarely spoke to customers.'),
  GyanWord('Perfunctory', 'ऊपरी / बेमन से किया गया', 'Done routinely, with little care or interest', 'The officer gave the file a perfunctory glance.'),
  GyanWord('Ostentatious', 'दिखावटी', 'Designed to impress; showy', 'An ostentatious wedding is not always a happy one.'),
  GyanWord('Surreptitious', 'चोरी-छिपे', 'Done secretly to avoid notice', 'He cast a surreptitious glance at his neighbour\'s screen.'),
  GyanWord('Exacerbate', 'बिगाड़ना / भड़काना', 'To make a problem worse', 'High inflation can exacerbate poverty.'),
  GyanWord('Egregious', 'घोर / बेहद बुरा', 'Shockingly bad', 'It was an egregious error in the balance sheet.'),
  GyanWord('Nefarious', 'दुष्ट / कुख्यात', 'Wicked or criminal', 'Police uncovered a nefarious scheme to defraud banks.'),
  GyanWord('Acrimony', 'कटुता', 'Bitterness in speech or manner', 'The talks ended in acrimony.'),
  GyanWord('Alacrity', 'तत्परता / फुर्ती', 'Brisk and cheerful readiness', 'She accepted the offer with alacrity.'),
  GyanWord('Anomaly', 'विसंगति', 'Something that deviates from what is normal', 'The sudden spike in deposits was an anomaly.'),
  GyanWord('Appease', 'शांत करना / तुष्ट करना', 'To calm someone by giving in to their demands', 'The government moved to appease the protesters.'),
  GyanWord('Arduous', 'कठिन / श्रमसाध्य', 'Involving great effort; tiring', 'Cracking a bank exam needs arduous preparation.'),
  GyanWord('Austere', 'कठोर / सादा', 'Severe; without luxury or comfort', 'He led an austere life.'),
  GyanWord('Belligerent', 'झगड़ालू / युद्धप्रिय', 'Hostile and aggressive', 'The belligerent customer shouted at the cashier.'),
  GyanWord('Circumspect', 'सतर्क / सोच-समझकर चलने वाला', 'Careful to consider the consequences before acting', 'Banks are circumspect while lending to risky borrowers.'),
  GyanWord('Clandestine', 'गुप्त', 'Kept secret, often because it is illegal', 'The clandestine meeting was held at midnight.'),
  GyanWord('Cogent', 'तर्कसंगत / प्रभावशाली', 'Clear, logical and convincing', 'She presented a cogent argument for the reform.'),
  GyanWord('Complacent', 'आत्मसंतुष्ट', 'Smugly satisfied and unaware of danger', 'Do not become complacent after one good mock score.'),
  GyanWord('Conundrum', 'पहेली / उलझन', 'A confusing and difficult problem', 'Rising prices pose a conundrum for policymakers.'),
  GyanWord('Debacle', 'भारी विफलता', 'A sudden and complete failure', 'The merger turned into a financial debacle.'),
  GyanWord('Deleterious', 'हानिकारक', 'Causing harm or damage', 'Smoking has a deleterious effect on health.'),
  GyanWord('Diatribe', 'कटु आलोचना / तीखा भाषण', 'A bitter verbal attack', 'He launched into a diatribe against the system.'),
  GyanWord('Disparage', 'निंदा करना / नीचा दिखाना', 'To speak of someone as having little value', 'Never disparage another candidate\'s effort.'),
  GyanWord('Dogmatic', 'हठधर्मी', 'Asserting opinions as undeniable truth', 'A dogmatic approach leaves no room for debate.'),
  GyanWord('Enigma', 'रहस्य / पहेली', 'A mysterious or puzzling person or thing', 'The cause of the sudden fall remains an enigma.'),
  GyanWord('Fastidious', 'नुक्ताचीन / अति सावधान', 'Very attentive to detail; hard to please', 'He is fastidious about his accounts.'),
  GyanWord('Fervent', 'उत्कट / जोशीला', 'Showing intense and sincere feeling', 'She made a fervent appeal for help.'),
  GyanWord('Fallacy', 'भ्रांति / तर्कदोष', 'A mistaken belief based on faulty reasoning', 'It is a fallacy that expensive coaching guarantees selection.'),
  GyanWord('Garrulous', 'बातूनी', 'Excessively talkative', 'My garrulous neighbour talks for hours.'),
  GyanWord('Gullible', 'भोला / आसानी से बहकने वाला', 'Easily deceived or persuaded', 'Gullible people fall for fake investment schemes.'),
  GyanWord('Hegemony', 'आधिपत्य / वर्चस्व', 'Dominance of one state or group over others', 'The empire established hegemony over the region.'),
  GyanWord('Iconoclast', 'रूढ़िभंजक', 'A person who attacks cherished beliefs and traditions', 'The iconoclast challenged every old tradition.'),
  GyanWord('Impeccable', 'बेदाग़ / त्रुटिहीन', 'Faultless; without any mistake', 'He has an impeccable record of service.'),
  GyanWord('Incessant', 'लगातार / अविराम', 'Continuing without pause', 'Incessant rain flooded the town.'),
  GyanWord('Indolent', 'आलसी / निठल्ला', 'Lazy; avoiding effort', 'An indolent attitude never leads to success.'),
  GyanWord('Intrepid', 'निडर', 'Fearless and adventurous', 'The intrepid climber reached the summit.'),
  GyanWord('Judicious', 'विवेकपूर्ण', 'Showing good judgement and sense', 'Judicious use of time is the key to success.'),
  GyanWord('Laconic', 'संक्षिप्त बोलने वाला', 'Using very few words', 'His laconic reply ended the argument.'),
  GyanWord('Mitigate', 'कम करना / हल्का करना', 'To make less severe or harmful', 'Insurance helps mitigate financial risk.'),
  GyanWord('Mercurial', 'चंचल / अस्थिर स्वभाव का', 'Unpredictably changing in mood', 'The mercurial manager changed his mind every hour.'),
  GyanWord('Nonchalant', 'बेपरवाह', 'Calm and seemingly unconcerned', 'She was nonchalant about the result.'),
  GyanWord('Opulent', 'वैभवशाली / समृद्ध', 'Rich and luxurious', 'The palace had an opulent interior.'),
  GyanWord('Panacea', 'रामबाण / हर रोग की दवा', 'A solution believed to cure all problems', 'Technology is not a panacea for every social problem.'),
  GyanWord('Paradigm', 'आदर्श-प्रतिमान / ढाँचा', 'A typical pattern or model of something', 'Digital payments created a new paradigm in banking.'),
  GyanWord('Placate', 'मनाना / शांत करना', 'To make someone less angry', 'The manager tried to placate the angry customer.'),
  GyanWord('Prolific', 'अत्यधिक रचनाशील / उपजाऊ', 'Producing a great deal', 'He was a prolific writer.'),
  GyanWord('Quixotic', 'अव्यावहारिक आदर्शवादी', 'Idealistic but unrealistic', 'It was a quixotic plan to end poverty overnight.'),
  GyanWord('Salient', 'प्रमुख / उल्लेखनीय', 'Most noticeable or important', 'Note the salient features of the scheme.'),
  GyanWord('Sanguine', 'आशावान', 'Optimistic, especially in a difficult situation', 'Economists are sanguine about growth.'),
  GyanWord('Scrupulous', 'ईमानदार / सतर्क', 'Diligent, careful and honest', 'A bank clerk must be scrupulous about records.'),
  GyanWord('Succinct', 'संक्षिप्त', 'Briefly and clearly expressed', 'Keep your answer succinct.'),
  GyanWord('Tenuous', 'कमज़ोर / क्षीण', 'Very weak or slight', 'The link between the two events is tenuous.'),
  GyanWord('Transient', 'अस्थायी / क्षणिक', 'Lasting only for a short time', 'The gains in the market were transient.'),
  GyanWord('Truculent', 'उग्र / झगड़ालू', 'Eager or quick to argue or fight', 'A truculent mob gathered outside the office.'),
  GyanWord('Vociferous', 'मुखर / शोर मचाने वाला', 'Loud and forceful in expressing opinions', 'Vociferous protests broke out in the hall.'),
  GyanWord('Vacillate', 'डगमगाना / असमंजस में रहना', 'To waver between different options', 'Do not vacillate between answers on exam day.'),
  GyanWord('Venerate', 'पूजना / अत्यंत सम्मान करना', 'To regard with great respect', 'People venerate their teachers.'),
  GyanWord('Wane', 'घटना / क्षीण होना', 'To decrease gradually in strength', 'His interest began to wane.'),
  GyanWord('Zealot', 'कट्टर / अति उत्साही', 'A fanatical supporter of a cause', 'A zealot ignores every opposing view.'),
];

// Hard-level GS / General Science / Static GK facts (71 facts)
const List<GyanFact> kGyanFacts = [
  GyanFact('Vitamin B12 (cobalamin) is the only vitamin that contains a metal, cobalt; its deficiency causes pernicious anaemia.', 'विटामिन B12 (कोबालामिन) एकमात्र विटामिन है जिसमें धातु (कोबाल्ट) होती है; इसकी कमी से पर्निशियस एनीमिया होता है।'),
  GyanFact('The 42nd Amendment (1976) added the words Socialist, Secular and Integrity to the Preamble.', '42वें संशोधन (1976) ने प्रस्तावना में \'समाजवादी\', \'पंथनिरपेक्ष\' और \'अखंडता\' शब्द जोड़े।'),
  GyanFact('India\'s Standard Meridian, 82°30′E, passes near Mirzapur in Uttar Pradesh, and Indian Standard Time is UTC+5:30.', 'भारत की मानक देशांतर रेखा 82°30′ पूर्व उत्तर प्रदेश के मिर्ज़ापुर के पास से गुज़रती है, और भारतीय मानक समय UTC+5:30 है।'),
  GyanFact('The Revolt of 1857 began at Meerut on 10 May 1857; in Lucknow it was led by Begum Hazrat Mahal.', '1857 का विद्रोह 10 मई 1857 को मेरठ से शुरू हुआ; लखनऊ में इसका नेतृत्व बेगम हज़रत महल ने किया।'),
  GyanFact('The RBI was established on 1 April 1935 under the RBI Act, 1934, and was nationalised on 1 January 1949.', 'RBI की स्थापना RBI अधिनियम 1934 के तहत 1 अप्रैल 1935 को हुई और 1 जनवरी 1949 को इसका राष्ट्रीयकरण हुआ।'),
  GyanFact('Mitochondria carry their own DNA and ribosomes, so they are called semi-autonomous cell organelles.', 'माइटोकॉन्ड्रिया में अपना DNA और राइबोसोम होते हैं, इसलिए इन्हें अर्ध-स्वायत्त कोशिकांग कहा जाता है।'),
  GyanFact('Article 21A, added by the 86th Amendment (2002), makes education a fundamental right for children aged 6 to 14.', '86वें संशोधन (2002) से जुड़ा अनुच्छेद 21A 6 से 14 वर्ष के बच्चों के लिए शिक्षा को मौलिक अधिकार बनाता है।'),
  GyanFact('The Tropic of Cancer passes through 8 Indian states: Gujarat, Rajasthan, Madhya Pradesh, Chhattisgarh, Jharkhand, West Bengal, Tripura and Mizoram.', 'कर्क रेखा भारत के 8 राज्यों से गुज़रती है: गुजरात, राजस्थान, मध्य प्रदेश, छत्तीसगढ़, झारखंड, पश्चिम बंगाल, त्रिपुरा और मिज़ोरम।'),
  GyanFact('The Chauri Chaura incident (Gorakhpur, 4 February 1922) made Gandhi withdraw the Non-Cooperation Movement.', 'चौरी-चौरा कांड (गोरखपुर, 4 फ़रवरी 1922) के बाद गांधीजी ने असहयोग आंदोलन वापस ले लिया।'),
  GyanFact('NABARD was set up on 12 July 1982 on the recommendation of the Shivaraman Committee.', 'नाबार्ड की स्थापना शिवरामन समिति की सिफ़ारिश पर 12 जुलाई 1982 को हुई।'),
  GyanFact('Beta cells of the islets of Langerhans in the pancreas secrete insulin, while alpha cells secrete glucagon.', 'अग्न्याशय की लैंगरहैंस द्वीपिकाओं की बीटा कोशिकाएँ इंसुलिन और अल्फा कोशिकाएँ ग्लूकागन स्रावित करती हैं।'),
  GyanFact('Fundamental Duties (Part IV-A, Article 51A) were added by the 42nd Amendment on the Swaran Singh Committee\'s advice; there are now 11 duties.', 'मौलिक कर्तव्य (भाग IV-क, अनुच्छेद 51A) स्वर्ण सिंह समिति की सिफ़ारिश पर 42वें संशोधन से जुड़े; अब इनकी संख्या 11 है।'),
  GyanFact('The Ganga and Yamuna meet at Prayagraj (Triveni Sangam); the Ghaghara is the Ganga\'s largest tributary by volume.', 'गंगा और यमुना प्रयागराज (त्रिवेणी संगम) में मिलती हैं; घाघरा जल-मात्रा के हिसाब से गंगा की सबसे बड़ी सहायक नदी है।'),
  GyanFact('The Kakori train action took place on 9 August 1925 near Lucknow; Ram Prasad Bismil and Ashfaqulla Khan were among those hanged for it.', 'काकोरी ट्रेन एक्शन 9 अगस्त 1925 को लखनऊ के पास हुआ; राम प्रसाद बिस्मिल और अशफ़ाक़उल्ला खाँ को इसी मामले में फाँसी हुई।'),
  GyanFact('India nationalised 14 major banks in 1969 and 6 more in 1980.', 'भारत ने 1969 में 14 बड़े बैंकों और 1980 में 6 और बैंकों का राष्ट्रीयकरण किया।'),
  GyanFact('Down syndrome is trisomy 21 (47 chromosomes), Turner syndrome is 45,X and Klinefelter syndrome is 47,XXY.', 'डाउन सिंड्रोम ट्राइसोमी-21 (47 गुणसूत्र), टर्नर सिंड्रोम 45,X और क्लाइनफेल्टर सिंड्रोम 47,XXY है।'),
  GyanFact('The Tenth Schedule (anti-defection law) was added by the 52nd Amendment in 1985.', 'दसवीं अनुसूची (दल-बदल विरोधी कानून) 1985 में 52वें संशोधन द्वारा जोड़ी गई।'),
  GyanFact('Uttar Pradesh has 75 districts and 18 divisions, and borders 8 states plus Delhi (and Nepal).', 'उत्तर प्रदेश में 75 जिले और 18 मंडल हैं; इसकी सीमा 8 राज्यों, दिल्ली (और नेपाल) से लगती है।'),
  GyanFact('The Lucknow Pact (1916) brought the Congress and the Muslim League together on common demands.', 'लखनऊ समझौते (1916) में कांग्रेस और मुस्लिम लीग साझा माँगों पर एक साथ आए।'),
  GyanFact('SEBI became a statutory body in 1992, and the Planning Commission was replaced by NITI Aayog on 1 January 2015.', 'SEBI को 1992 में वैधानिक दर्जा मिला और 1 जनवरी 2015 को योजना आयोग की जगह नीति आयोग बना।'),
  GyanFact('Haemophilia and colour blindness are X-linked recessive disorders, so they appear more often in males.', 'हीमोफीलिया और वर्णांधता X-सहलग्न अप्रभावी विकार हैं, इसलिए ये पुरुषों में अधिक होते हैं।'),
  GyanFact('The 73rd Amendment (1992) gave constitutional status to Panchayati Raj (Part IX), and the 74th Amendment to urban local bodies (Part IX-A).', '73वें संशोधन (1992) ने पंचायती राज (भाग IX) और 74वें संशोधन ने शहरी स्थानीय निकायों (भाग IX-क) को संवैधानिक दर्जा दिया।'),
  GyanFact('The United Provinces of Agra and Oudh (1902) was renamed Uttar Pradesh on 24 January 1950; Uttarakhand was carved out on 9 November 2000.', 'आगरा और अवध संयुक्त प्रांत (1902) का नाम 24 जनवरी 1950 को उत्तर प्रदेश हुआ; 9 नवंबर 2000 को उत्तराखंड अलग बना।'),
  GyanFact('The Allahabad Pillar inscription (Prayag Prashasti) by Harishena describes Samudragupta, whom V. A. Smith called the Napoleon of India.', 'हरिषेण की प्रयाग प्रशस्ति (इलाहाबाद स्तंभ लेख) में समुद्रगुप्त का वर्णन है, जिन्हें वी. ए. स्मिथ ने \'भारत का नेपोलियन\' कहा।'),
  GyanFact('Only the one-rupee note is issued by the Government of India (signed by the Finance Secretary); every other note carries the RBI Governor\'s signature.', 'केवल एक रुपये का नोट भारत सरकार जारी करती है (वित्त सचिव के हस्ताक्षर); बाकी सभी नोटों पर RBI गवर्नर के हस्ताक्षर होते हैं।'),
  GyanFact('Chlorophyll contains magnesium, haemoglobin contains iron and haemocyanin (in some molluscs) contains copper.', 'क्लोरोफिल में मैग्नीशियम, हीमोग्लोबिन में लोहा और हीमोसायनिन (कुछ मोलस्क में) में ताँबा होता है।'),
  GyanFact('GST was introduced by the 101st Amendment, the GST Council comes under Article 279A, and GST began on 1 July 2017.', 'GST 101वें संशोधन से आया, GST परिषद अनुच्छेद 279A के अंतर्गत है और GST 1 जुलाई 2017 से लागू हुआ।'),
  GyanFact('The Allahabad High Court was established in 1866 at Agra and shifted to Allahabad (now Prayagraj) in 1869; its Lucknow bench began in 1948.', 'इलाहाबाद उच्च न्यायालय 1866 में आगरा में स्थापित हुआ और 1869 में इलाहाबाद (अब प्रयागराज) आया; इसकी लखनऊ पीठ 1948 में शुरू हुई।'),
  GyanFact('Harshavardhana ruled from Kannauj, and the Chinese pilgrim Xuanzang visited India during his reign.', 'हर्षवर्धन ने कन्नौज से शासन किया, और उनके काल में चीनी यात्री ह्वेनसांग भारत आया।'),
  GyanFact('The Imperial Bank of India was taken over to form the State Bank of India in 1955.', 'इंपीरियल बैंक ऑफ इंडिया को लेकर 1955 में भारतीय स्टेट बैंक (SBI) बनाया गया।'),
  GyanFact('Rhizobium bacteria fix atmospheric nitrogen in the root nodules of leguminous plants.', 'राइज़ोबियम बैक्टीरिया दलहनी पौधों की जड़ों की गाँठों में वायुमंडलीय नाइट्रोजन का स्थिरीकरण करते हैं।'),
  GyanFact('The Kesavananda Bharati case (1973) laid down the Basic Structure doctrine: Parliament cannot alter the basic structure of the Constitution.', 'केशवानंद भारती मामले (1973) ने मूल ढाँचे का सिद्धांत दिया: संसद संविधान के मूल ढाँचे को नहीं बदल सकती।'),
  GyanFact('Taj Mahal, Agra Fort and Fatehpur Sikri are Uttar Pradesh\'s three UNESCO World Heritage Sites.', 'ताजमहल, आगरा का किला और फतेहपुर सीकरी उत्तर प्रदेश के तीन यूनेस्को विश्व धरोहर स्थल हैं।'),
  GyanFact('The Lion Capital of Ashoka from Sarnath (near Varanasi) is India\'s national emblem, adopted on 26 January 1950.', 'सारनाथ (वाराणसी के पास) का अशोक का सिंह स्तंभ शीर्ष भारत का राष्ट्रीय चिह्न है, जिसे 26 जनवरी 1950 को अपनाया गया।'),
  GyanFact('The FRBM Act, 2003 aims at fiscal discipline, and India\'s financial year runs from 1 April to 31 March.', 'FRBM अधिनियम 2003 का उद्देश्य राजकोषीय अनुशासन है, और भारत का वित्तीय वर्ष 1 अप्रैल से 31 मार्च तक चलता है।'),
  GyanFact('In photosynthesis the light reaction takes place in the grana and the Calvin cycle (dark reaction) in the stroma of the chloroplast.', 'प्रकाश संश्लेषण में प्रकाश अभिक्रिया हरितलवक के ग्रेना में और कैल्विन चक्र (अप्रकाश अभिक्रिया) स्ट्रोमा में होता है।'),
  GyanFact('Article 280 provides for the Finance Commission (constituted every five years), Article 148 for the CAG and Article 324 for the Election Commission.', 'अनुच्छेद 280 वित्त आयोग (हर पाँच वर्ष में गठित), अनुच्छेद 148 नियंत्रक एवं महालेखा परीक्षक और अनुच्छेद 324 निर्वाचन आयोग से जुड़ा है।'),
  GyanFact('UP\'s famous crafts: Firozabad glass, Moradabad brass, Aligarh locks, Bhadohi carpets, Saharanpur wood carving and Lucknow chikankari.', 'यूपी के प्रसिद्ध उद्योग: फिरोज़ाबाद का काँच, मुरादाबाद का पीतल, अलीगढ़ के ताले, भदोही के कालीन, सहारनपुर की लकड़ी की नक्काशी और लखनऊ की चिकनकारी।'),
  GyanFact('Land revenue systems: Permanent Settlement (1793, Cornwallis, Bengal), Ryotwari (Thomas Munro, Madras) and Mahalwari (1822, mainly the North-Western Provinces, today\'s UP).', 'भू-राजस्व व्यवस्थाएँ: स्थायी बंदोबस्त (1793, कॉर्नवालिस, बंगाल), रैयतवाड़ी (थॉमस मुनरो, मद्रास) और महलवाड़ी (1822, मुख्यतः उत्तर-पश्चिमी प्रांत यानी आज का उत्तर प्रदेश)।'),
  GyanFact('The IMF and World Bank are headquartered in Washington D.C., the WTO in Geneva, the ADB in Manila, the AIIB in Beijing and the NDB in Shanghai.', 'IMF और विश्व बैंक का मुख्यालय वॉशिंगटन डी.सी., WTO का जिनेवा, ADB का मनीला, AIIB का बीजिंग और NDB का शंघाई में है।'),
  GyanFact('Osmium is the densest naturally occurring element; mercury (a metal) and bromine (a non-metal) are the only two elements that are liquid at room temperature.', 'ओस्मियम प्राकृतिक रूप से पाया जाने वाला सबसे सघन तत्व है; पारा (धातु) और ब्रोमीन (अधातु) कमरे के तापमान पर द्रव रहने वाले एकमात्र दो तत्व हैं।'),
  GyanFact('The Constituent Assembly first met on 9 December 1946 with Sachchidananda Sinha as interim president; the Drafting Committee under B. R. Ambedkar was set up on 29 August 1947.', 'संविधान सभा की पहली बैठक 9 दिसंबर 1946 को हुई (अंतरिम अध्यक्ष: सच्चिदानंद सिन्हा); बी. आर. अंबेडकर की अध्यक्षता में प्रारूप समिति 29 अगस्त 1947 को बनी।'),
  GyanFact('Kathak, whose major gharanas are Lucknow, Jaipur and Banaras, is one of India\'s 8 classical dances recognised by the Sangeet Natak Akademi (Sattriya was added in 2000).', 'कथक (लखनऊ, जयपुर और बनारस घराने) संगीत नाटक अकादमी द्वारा मान्य भारत के 8 शास्त्रीय नृत्यों में है (सत्रिया 2000 में जुड़ा)।'),
  GyanFact('Battles of Panipat: 1526 (Babur defeated Ibrahim Lodi), 1556 (Akbar\'s forces defeated Hemu) and 1761 (Ahmad Shah Abdali defeated the Marathas).', 'पानीपत की लड़ाइयाँ: 1526 (बाबर ने इब्राहिम लोदी को हराया), 1556 (अकबर की सेना ने हेमू को हराया) और 1761 (अहमद शाह अब्दाली ने मराठों को हराया)।'),
  GyanFact('Since 2017 the Union Budget is presented on 1 February, and the separate Railway Budget was merged with it.', '2017 से केंद्रीय बजट 1 फ़रवरी को पेश होता है और अलग रेल बजट को उसी में मिला दिया गया है।'),
  GyanFact('Bleaching powder is CaOCl2 (calcium oxychloride) and Plaster of Paris is CaSO4·½H2O (calcium sulphate hemihydrate).', 'ब्लीचिंग पाउडर CaOCl2 (कैल्शियम ऑक्सीक्लोराइड) और प्लास्टर ऑफ पेरिस CaSO4·½H2O (कैल्शियम सल्फेट हेमिहाइड्रेट) है।'),
  GyanFact('Uttar Pradesh has 403 Vidhan Sabha seats and 100 Vidhan Parishad seats, and sends 80 members to the Lok Sabha and 31 to the Rajya Sabha.', 'उत्तर प्रदेश में विधानसभा की 403 और विधान परिषद की 100 सीटें हैं; यह लोकसभा में 80 और राज्यसभा में 31 सदस्य भेजता है।'),
  GyanFact('Kangchenjunga (8,586 m) is the highest peak in India; the Tehri Dam (about 260 m) on the Bhagirathi is India\'s highest dam and Hirakud on the Mahanadi its longest.', 'कंचनजंगा (8,586 मीटर) भारत की सबसे ऊँची चोटी है; भागीरथी पर टिहरी बाँध (लगभग 260 मीटर) सबसे ऊँचा और महानदी पर हीराकुंड सबसे लंबा बाँध है।'),
  GyanFact('Lord Wellesley introduced the Subsidiary Alliance (first accepted by Hyderabad in 1798), and Lord Dalhousie the Doctrine of Lapse.', 'लॉर्ड वेलेज़ली ने सहायक संधि (हैदराबाद ने 1798 में पहली बार स्वीकार की) और लॉर्ड डलहौजी ने व्यपगत का सिद्धांत लागू किया।'),
  GyanFact('Galvanisation coats iron with zinc; zinc protects even a scratched surface because it is more reactive than iron (sacrificial protection).', 'गैल्वनीकरण में लोहे पर जस्ते की परत चढ़ती है; जस्ता लोहे से अधिक क्रियाशील है, इसलिए खरोंच लगने पर भी लोहे को जंग से बचाता है।'),
  GyanFact('Sarojini Naidu was Uttar Pradesh\'s first Governor and India\'s first woman Governor; Sucheta Kripalani of UP became India\'s first woman Chief Minister in 1963.', 'सरोजिनी नायडू उत्तर प्रदेश की पहली राज्यपाल और भारत की पहली महिला राज्यपाल थीं; यूपी की सुचेता कृपलानी 1963 में भारत की पहली महिला मुख्यमंत्री बनीं।'),
  GyanFact('Wular (J&K) is India\'s largest freshwater lake, Chilika (Odisha) its largest coastal lagoon, and Keibul Lamjao at Loktak is the world\'s only floating national park.', 'वुलर (J&K) भारत की सबसे बड़ी मीठे पानी की झील, चिल्का (ओडिशा) सबसे बड़ी तटीय लैगून है; लोकटक का केइबुल लामजाओ दुनिया का एकमात्र तैरता राष्ट्रीय उद्यान है।'),
  GyanFact('Gandhi returned to India on 9 January 1915 (Pravasi Bharatiya Diwas); his first satyagraha in India was at Champaran in 1917.', 'गांधीजी 9 जनवरी 1915 को भारत लौटे (प्रवासी भारतीय दिवस); भारत में उनका पहला सत्याग्रह 1917 में चंपारण में हुआ।'),
  GyanFact('Total internal reflection is the principle behind optical fibres, and it also explains the brilliance of a diamond.', 'पूर्ण आंतरिक परावर्तन ऑप्टिकल फाइबर का सिद्धांत है और यही हीरे की चमक का भी कारण है।'),
  GyanFact('The Supreme Court of India was inaugurated on 28 January 1950, two days after the Constitution came into force.', 'भारत का सर्वोच्च न्यायालय 28 जनवरी 1950 को, संविधान लागू होने के दो दिन बाद, शुरू हुआ।'),
  GyanFact('The Palk Strait separates India and Sri Lanka, the Ten Degree Channel separates the Andamans from the Nicobars, and Indira Point (Great Nicobar) is India\'s southernmost point.', 'पाक जलडमरूमध्य भारत और श्रीलंका को, दस डिग्री चैनल अंडमान को निकोबार से अलग करता है; इंदिरा पॉइंट (ग्रेट निकोबार) भारत का दक्षिणतम बिंदु है।'),
  GyanFact('The Poona Pact (1932) between Gandhi and Ambedkar replaced separate electorates for the Depressed Classes with reserved seats.', 'गांधीजी और अंबेडकर के बीच पूना समझौते (1932) ने दलित वर्गों के लिए अलग निर्वाचक मंडल की जगह आरक्षित सीटें दीं।'),
  GyanFact('The SI unit of magnetic flux density is the tesla, and that of magnetic flux is the weber.', 'चुंबकीय क्षेत्र (फ्लक्स घनत्व) की SI इकाई टेस्ला और चुंबकीय फ्लक्स की SI इकाई वेबर है।'),
  GyanFact('Lake Baikal in Russia is the world\'s deepest lake; the Nile is traditionally the longest river and the Amazon the largest by discharge.', 'रूस की बैकाल झील विश्व की सबसे गहरी झील है; नील को परंपरागत रूप से सबसे लंबी और अमेज़न को जल-प्रवाह में सबसे बड़ी नदी माना जाता है।'),
  GyanFact('The escape velocity from the Earth\'s surface is about 11.2 km/s.', 'पृथ्वी की सतह से पलायन वेग लगभग 11.2 किमी/सेकंड है।'),
  GyanFact('The Bharat Ratna was instituted in 1954; its first recipients were C. Rajagopalachari, S. Radhakrishnan and C. V. Raman.', 'भारत रत्न की शुरुआत 1954 में हुई; पहले सम्मानित व्यक्ति सी. राजगोपालाचारी, एस. राधाकृष्णन और सी. वी. रमन थे।'),
  GyanFact('The ozone layer lies in the stratosphere. The Montreal Protocol (1987) curbs ozone-depleting substances, and the Kigali Amendment (2016) phases down HFCs.', 'ओज़ोन परत समताप मंडल में है। मॉन्ट्रियल प्रोटोकॉल (1987) ओज़ोन-क्षयकारी पदार्थों और किगाली संशोधन (2016) HFC को घटाने से जुड़ा है।'),
  GyanFact('The first Jnanpith Award (1965) went to the Malayalam poet G. Sankara Kurup.', 'पहला ज्ञानपीठ पुरस्कार (1965) मलयालम कवि जी. शंकर कुरुप को मिला।'),
  GyanFact('Rain is called acid rain when its pH falls below 5.6.', 'वर्षा का pH 5.6 से कम हो जाए तो उसे अम्लीय वर्षा कहते हैं।'),
  GyanFact('Ramlila (2008), Yoga (2016) and the Kumbh Mela (2017) are on UNESCO\'s list of Intangible Cultural Heritage.', 'रामलीला (2008), योग (2016) और कुंभ मेला (2017) यूनेस्को की अमूर्त सांस्कृतिक विरासत सूची में हैं।'),
  GyanFact('Normal human blood has a pH of about 7.4, which is slightly alkaline.', 'सामान्य मानव रक्त का pH लगभग 7.4 होता है, जो हल्का क्षारीय है।'),
  GyanFact('Palynology is the study of pollen grains and spores.', 'पैलिनोलॉजी (परागाणु विज्ञान) में पराग कणों और बीजाणुओं का अध्ययन किया जाता है।'),
  GyanFact('The Sun\'s energy comes from the nuclear fusion of hydrogen into helium; its light takes about 8 minutes 20 seconds to reach the Earth.', 'सूर्य की ऊर्जा हाइड्रोजन के हीलियम में नाभिकीय संलयन से आती है; उसका प्रकाश पृथ्वी तक लगभग 8 मिनट 20 सेकंड में पहुँचता है।'),
  GyanFact('The liver is the largest gland of the human body, while the thyroid is the largest purely endocrine gland.', 'यकृत (लिवर) मानव शरीर की सबसे बड़ी ग्रंथि है, जबकि थायरॉइड सबसे बड़ी विशुद्ध अंतःस्रावी ग्रंथि है।'),
  GyanFact('J. C. Bose invented the crescograph to measure plant growth; Har Gobind Khorana shared the 1968 Nobel Prize in Medicine for deciphering the genetic code.', 'जे. सी. बोस ने पौधों की वृद्धि नापने के लिए क्रेस्कोग्राफ बनाया; हरगोविंद खुराना ने आनुवंशिक कूट समझने पर 1968 का चिकित्सा नोबेल साझा किया।'),
  GyanFact('C. V. Raman discovered the Raman effect in 1928, and National Science Day is celebrated on 28 February to mark it.', 'सी. वी. रमन ने 1928 में रमन प्रभाव खोजा, और उसी की याद में 28 फरवरी को राष्ट्रीय विज्ञान दिवस मनाया जाता है।'),
];
