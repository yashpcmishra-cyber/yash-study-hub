// =============================================================================
//  "Aaj ka Gyaan" ka content: Word of the Day + ek GK fact.
//  Roz date ke hisaab se ek-ek entry badalti hai (40 din ka cycle).
//  App ke andar bundled hai - internet / Firestore ki zaroorat nahi.
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

const List<GyanWord> kGyanWords = [
  GyanWord('Abate', 'कम होना / घटना', 'To become less intense', 'The storm began to abate by evening.'),
  GyanWord('Candid', 'स्पष्टवादी', 'Honest and straightforward', 'She gave a candid opinion about the plan.'),
  GyanWord('Diligent', 'मेहनती', 'Hard-working and careful', 'A diligent student revises every day.'),
  GyanWord('Eloquent', 'वाक्पटु', 'Fluent and persuasive in speech', 'His eloquent speech moved the crowd.'),
  GyanWord('Frugal', 'मितव्ययी', 'Careful about spending money', 'They led a frugal life.'),
  GyanWord('Gregarious', 'मिलनसार', 'Fond of company; sociable', 'He is a gregarious person who loves parties.'),
  GyanWord('Hostile', 'शत्रुतापूर्ण', 'Unfriendly; opposed', 'The crowd was hostile to the proposal.'),
  GyanWord('Imminent', 'निकट / आसन्न', 'About to happen', 'The exam is imminent, so start revising.'),
  GyanWord('Jubilant', 'उल्लसित', 'Feeling great joy', 'The team was jubilant after the win.'),
  GyanWord('Keen', 'उत्सुक / तीव्र', 'Eager; very sharp', 'She has a keen interest in science.'),
  GyanWord('Lucid', 'स्पष्ट / सुबोध', 'Clear and easy to understand', 'The teacher gave a lucid explanation.'),
  GyanWord('Meticulous', 'बारीकी से सावधान', 'Very careful about details', 'He is meticulous about his notes.'),
  GyanWord('Nostalgia', 'पुरानी यादों की तड़प', 'Sentimental longing for the past', 'The old song filled him with nostalgia.'),
  GyanWord('Obsolete', 'अप्रचलित', 'No longer in use', 'Floppy disks are now obsolete.'),
  GyanWord('Pragmatic', 'व्यावहारिक', 'Practical rather than theoretical', 'We need a pragmatic solution.'),
  GyanWord('Quell', 'दबाना / शांत करना', 'To put an end to; to suppress', 'Police acted fast to quell the riot.'),
  GyanWord('Resilient', 'लचीला / हार न मानने वाला', 'Able to recover quickly', 'Resilient students bounce back after failure.'),
  GyanWord('Scrutinize', 'बारीकी से जाँचना', 'To examine very carefully', 'Scrutinize every option before answering.'),
  GyanWord('Tenacious', 'दृढ़ / अडिग', 'Holding firmly to a goal', 'Her tenacious effort finally paid off.'),
  GyanWord('Ubiquitous', 'सर्वव्यापी', 'Found everywhere', 'Smartphones are ubiquitous today.'),
  GyanWord('Vindicate', 'निर्दोष सिद्ध करना', 'To clear of blame; to prove right', 'The report vindicated the officer.'),
  GyanWord('Wary', 'सतर्क', 'Cautious about possible danger', 'Be wary of fake news.'),
  GyanWord('Zeal', 'उत्साह', 'Great energy for a cause', 'He worked with great zeal.'),
  GyanWord('Ambiguous', 'अस्पष्ट / दो अर्थ वाला', 'Open to more than one meaning', 'The question was ambiguous.'),
  GyanWord('Benevolent', 'परोपकारी', 'Kind and generous', 'A benevolent king helped the poor.'),
  GyanWord('Conceal', 'छिपाना', 'To hide', 'He tried to conceal his disappointment.'),
  GyanWord('Deteriorate', 'बिगड़ना', 'To become worse', 'His health began to deteriorate.'),
  GyanWord('Endeavour', 'प्रयास', 'A serious attempt; effort', 'Make every endeavour to finish on time.'),
  GyanWord('Fragile', 'नाज़ुक', 'Easily broken', 'Handle the fragile glass with care.'),
  GyanWord('Hypocrisy', 'पाखंड', 'Saying one thing, doing another', 'Preaching honesty while cheating is hypocrisy.'),
  GyanWord('Inevitable', 'अपरिहार्य', 'Certain to happen', 'Change is inevitable.'),
  GyanWord('Lethargic', 'सुस्त', 'Lacking energy', 'The heat made everyone lethargic.'),
  GyanWord('Mundane', 'साधारण / नीरस', 'Ordinary and dull', 'He was tired of mundane tasks.'),
  GyanWord('Obstinate', 'ज़िद्दी', 'Stubborn', 'An obstinate child refuses advice.'),
  GyanWord('Prudent', 'विवेकी / समझदार', 'Acting with care and good judgement', 'It is prudent to save some money.'),
  GyanWord('Reluctant', 'अनिच्छुक', 'Unwilling', 'She was reluctant to speak in public.'),
  GyanWord('Spontaneous', 'स्वाभाविक / अनायास', 'Done naturally, without planning', 'The crowd gave a spontaneous cheer.'),
  GyanWord('Trivial', 'तुच्छ', 'Of little importance', 'Do not waste time on trivial matters.'),
  GyanWord('Verbose', 'वाचाल / शब्दबहुल', 'Using more words than needed', 'His verbose answer confused everyone.'),
  GyanWord('Withstand', 'सहना / टिके रहना', 'To resist or endure', 'The bridge can withstand strong floods.'),
];

const List<GyanFact> kGyanFacts = [
  GyanFact('The Ashoka Chakra on the Indian flag has 24 spokes.', 'भारतीय तिरंगे के अशोक चक्र में 24 तीलियाँ होती हैं।'),
  GyanFact('The Indian National Flag was adopted by the Constituent Assembly on 22 July 1947.', 'राष्ट्रीय ध्वज को संविधान सभा ने 22 जुलाई 1947 को अपनाया।'),
  GyanFact("'Jana Gana Mana' was written by Rabindranath Tagore and adopted as the National Anthem on 24 January 1950.", "'जन गण मन' रवींद्रनाथ टैगोर ने लिखा; 24 जनवरी 1950 को राष्ट्रगान बना।"),
  GyanFact("'Vande Mataram' was written by Bankim Chandra Chattopadhyay (from the novel Anandamath).", "'वंदे मातरम्' बंकिमचंद्र चट्टोपाध्याय ने लिखा (उपन्यास आनंदमठ से)।"),
  GyanFact("India's national animal is the Tiger, national bird the Peacock, national flower the Lotus.", 'भारत का राष्ट्रीय पशु बाघ, राष्ट्रीय पक्षी मोर और राष्ट्रीय फूल कमल है।'),
  GyanFact("India's national aquatic animal is the Ganges river dolphin.", 'भारत का राष्ट्रीय जलीय जीव गंगा नदी की डॉल्फ़िन है।'),
  GyanFact('The capital of British India moved from Calcutta to Delhi (announced 1911, inaugurated 1931).', 'ब्रिटिश भारत की राजधानी कलकत्ता से दिल्ली आई (घोषणा 1911, उद्घाटन 1931)।'),
  GyanFact('Jupiter is the largest planet and Mercury the smallest; Venus is the hottest.', 'बृहस्पति सबसे बड़ा ग्रह, बुध सबसे छोटा और शुक्र सबसे गर्म ग्रह है।'),
  GyanFact("Chandrayaan-3 landed near the Moon's south pole on 23 August 2023.", 'चंद्रयान-3 23 अगस्त 2023 को चाँद के दक्षिणी ध्रुव के पास उतरा।'),
  GyanFact("ISRO was formed in 1969 (HQ: Bengaluru). India's first satellite Aryabhata was launched in 1975.", 'ISRO की स्थापना 1969 में हुई (मुख्यालय: बेंगलुरु)। पहला उपग्रह आर्यभट्ट 1975 में छोड़ा गया।'),
  GyanFact("Bharat Ratna, India's highest civilian award, was instituted in 1954.", 'भारत का सर्वोच्च नागरिक सम्मान भारत रत्न 1954 में शुरू हुआ।'),
  GyanFact('Mahatma Gandhi was born on 2 October 1869 in Porbandar, Gujarat.', 'महात्मा गांधी का जन्म 2 अक्टूबर 1869 को पोरबंदर (गुजरात) में हुआ।'),
  GyanFact('Indira Gandhi was the first woman Prime Minister of India.', 'इंदिरा गांधी भारत की पहली महिला प्रधानमंत्री थीं।'),
  GyanFact('Pratibha Patil became the first woman President of India in 2007.', 'प्रतिभा पाटिल 2007 में भारत की पहली महिला राष्ट्रपति बनीं।'),
  GyanFact('Rabindranath Tagore won the Nobel Prize in Literature in 1913, the first Asian to do so.', 'रवींद्रनाथ टैगोर ने 1913 में साहित्य का नोबेल जीता, ऐसा करने वाले पहले एशियाई।'),
  GyanFact('C. V. Raman won the Nobel Prize in Physics in 1930 for the Raman Effect.', 'सी. वी. रमन ने रमन प्रभाव के लिए 1930 में भौतिकी का नोबेल जीता।'),
  GyanFact('The Taj Mahal in Agra was built by Shah Jahan on the banks of the Yamuna.', 'आगरा का ताजमहल शाहजहाँ ने यमुना किनारे बनवाया।'),
  GyanFact('The Konark Sun Temple in Odisha is a UNESCO World Heritage Site.', 'ओडिशा का कोणार्क सूर्य मंदिर यूनेस्को विश्व धरोहर स्थल है।'),
  GyanFact('The stapes bone in the ear is the smallest bone; the femur is the largest.', 'कान की स्टेपीज़ सबसे छोटी हड्डी और फीमर सबसे बड़ी हड्डी है।'),
  GyanFact('The Pacific is the largest ocean; its Mariana Trench holds the deepest point on Earth.', 'प्रशांत सबसे बड़ा महासागर है; मारियाना गर्त पृथ्वी का सबसे गहरा स्थान है।'),
  GyanFact('Mount Everest is 8,849 m high (measured jointly by Nepal and China in 2020).', 'माउंट एवरेस्ट की ऊँचाई 8,849 मीटर है (नेपाल-चीन ने 2020 में नापी)।'),
  GyanFact('India became the most populous country in 2023, according to UN estimates.', 'UN के अनुमान के अनुसार भारत 2023 में सबसे अधिक आबादी वाला देश बना।'),
  GyanFact('Neeraj Chopra won gold in javelin at the Tokyo Olympics, India\u2019s first Olympic gold in athletics.', 'नीरज चोपड़ा ने टोक्यो ओलंपिक में भाला फेंक में स्वर्ण जीता, एथलेटिक्स में भारत का पहला ओलंपिक स्वर्ण।'),
  GyanFact('India won the Cricket World Cup in 1983 (Kapil Dev) and 2011 (M. S. Dhoni).', 'भारत ने क्रिकेट विश्व कप 1983 (कपिल देव) और 2011 (एम. एस. धोनी) में जीता।'),
  GyanFact('India has won 8 Olympic gold medals in hockey (1928 to 1980).', 'भारत ने हॉकी में 8 ओलंपिक स्वर्ण पदक जीते हैं (1928 से 1980)।'),
  GyanFact('National Sports Day is on 29 August, the birthday of Major Dhyan Chand.', 'राष्ट्रीय खेल दिवस 29 अगस्त को मेजर ध्यानचंद के जन्मदिन पर मनाया जाता है।'),
  GyanFact("Teachers' Day is on 5 September; Children's Day on 14 November.", 'शिक्षक दिवस 5 सितंबर और बाल दिवस 14 नवंबर को मनाया जाता है।'),
  GyanFact('National Youth Day (12 January) marks the birth of Swami Vivekananda.', 'राष्ट्रीय युवा दिवस (12 जनवरी) स्वामी विवेकानंद की जयंती पर मनाया जाता है।'),
  GyanFact('World Environment Day is on 5 June and World Health Day on 7 April.', 'विश्व पर्यावरण दिवस 5 जून और विश्व स्वास्थ्य दिवस 7 अप्रैल को होता है।'),
  GyanFact('Aravalli is among the oldest fold mountains in the world; the Himalayas are among the youngest.', 'अरावली विश्व की सबसे पुरानी वलित पर्वतमालाओं में है; हिमालय सबसे नई में से एक है।'),
  GyanFact('The Sundarbans is the largest mangrove forest in the world and home to the Bengal tiger.', 'सुंदरबन विश्व का सबसे बड़ा मैंग्रोव वन है और बंगाल टाइगर का घर है।'),
  GyanFact('Kaziranga (Assam) is famous for the one-horned rhinoceros; Gir (Gujarat) for the Asiatic lion.', 'काजीरंगा (असम) एक सींग वाले गैंडे और गिर (गुजरात) एशियाई शेर के लिए प्रसिद्ध है।'),
  GyanFact("Jim Corbett is India's oldest national park (established 1936).", 'जिम कॉर्बेट भारत का सबसे पुराना राष्ट्रीय उद्यान है (1936)।'),
  GyanFact('Charles Babbage is called the Father of the Computer; Tim Berners-Lee invented the World Wide Web.', 'चार्ल्स बैबेज को कंप्यूटर का जनक कहते हैं; टिम बर्नर्स-ली ने वर्ल्ड वाइड वेब बनाया।'),
  GyanFact('Digital India was launched on 1 July 2015 and the Jan Dhan Yojana on 28 August 2014.', 'डिजिटल इंडिया 1 जुलाई 2015 और जन धन योजना 28 अगस्त 2014 को शुरू हुई।'),
  GyanFact('UPI was launched by NPCI in 2016 and changed how India pays.', 'UPI को NPCI ने 2016 में शुरू किया और इसने भारत में भुगतान का तरीका बदल दिया।'),
  GyanFact('G. V. Mavalankar was the first Speaker of the Lok Sabha.', 'जी. वी. मावलंकर लोकसभा के पहले अध्यक्ष थे।'),
  GyanFact('Rakesh Sharma became the first Indian to travel to space in 1984.', 'राकेश शर्मा 1984 में अंतरिक्ष जाने वाले पहले भारतीय बने।'),
  GyanFact('Viswanathan Anand became India\u2019s first chess Grandmaster in 1988.', 'विश्वनाथन आनंद 1988 में भारत के पहले शतरंज ग्रैंडमास्टर बने।'),
  GyanFact('NH 44 (Srinagar to Kanyakumari) is the longest national highway in India.', 'NH 44 (श्रीनगर से कन्याकुमारी) भारत का सबसे लंबा राष्ट्रीय राजमार्ग है।'),
  GyanFact('Brahmagupta (628 CE) gave rules for using zero as a number.', 'ब्रह्मगुप्त (628 ई.) ने शून्य को एक संख्या की तरह इस्तेमाल करने के नियम दिए।'),
];
