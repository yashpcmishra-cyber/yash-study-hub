// =============================================================================
//  Important Days ka content (app ke andar hi bundled - internet / Firestore nahi).
//  Sirf FIXED tareekh wale din hain (tyohaar jinki tareekh badalti hai, jaise
//  Diwali / Holi, isme nahi hain). Naya din jodna ho to kisi bhi jagah ek line
//  add kar do: ImportantDay(mahina, tareekh, 'type', 'English', 'Hindi').
//  type: 'india' = India ke din, 'world' = UN / antarrashtriya din,
//        'state' = rajya sthapna diwas.
// =============================================================================

class ImportantDay {
  final int month; // 1-12
  final int day; // 1-31
  final String type; // 'india' | 'world' | 'state'
  final String en;
  final String hi;
  const ImportantDay(this.month, this.day, this.type, this.en, this.hi);
}

const List<String> kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<ImportantDay> kImportantDays = [
  // ------------------------------------------------------------ JANUARY
  ImportantDay(1, 1, 'world', 'Global Family Day', 'वैश्विक परिवार दिवस'),
  ImportantDay(1, 4, 'world', 'World Braille Day', 'विश्व ब्रेल दिवस'),
  ImportantDay(1, 9, 'india', 'Pravasi Bharatiya Diwas', 'प्रवासी भारतीय दिवस'),
  ImportantDay(1, 10, 'world', 'World Hindi Day', 'विश्व हिंदी दिवस'),
  ImportantDay(1, 12, 'india', 'National Youth Day (Swami Vivekananda Jayanti)', 'राष्ट्रीय युवा दिवस (स्वामी विवेकानंद जयंती)'),
  ImportantDay(1, 15, 'india', 'Indian Army Day', 'भारतीय सेना दिवस'),
  ImportantDay(1, 23, 'india', 'Netaji Subhas Chandra Bose Jayanti (Parakram Diwas)', 'नेताजी सुभाष चंद्र बोस जयंती (पराक्रम दिवस)'),
  ImportantDay(1, 24, 'india', 'National Girl Child Day', 'राष्ट्रीय बालिका दिवस'),
  ImportantDay(1, 24, 'state', 'Uttar Pradesh Diwas', 'उत्तर प्रदेश दिवस'),
  ImportantDay(1, 24, 'world', 'International Day of Education', 'अंतरराष्ट्रीय शिक्षा दिवस'),
  ImportantDay(1, 25, 'india', "National Voters' Day", 'राष्ट्रीय मतदाता दिवस'),
  ImportantDay(1, 25, 'india', 'National Tourism Day', 'राष्ट्रीय पर्यटन दिवस'),
  ImportantDay(1, 26, 'india', 'Republic Day', 'गणतंत्र दिवस'),
  ImportantDay(1, 30, 'india', "Martyrs' Day (Shaheed Diwas)", 'शहीद दिवस'),

  // ----------------------------------------------------------- FEBRUARY
  ImportantDay(2, 2, 'world', 'World Wetlands Day', 'विश्व आर्द्रभूमि दिवस'),
  ImportantDay(2, 4, 'world', 'World Cancer Day', 'विश्व कैंसर दिवस'),
  ImportantDay(2, 13, 'world', 'World Radio Day', 'विश्व रेडियो दिवस'),
  ImportantDay(2, 13, 'india', "National Women's Day (Sarojini Naidu Jayanti)", 'राष्ट्रीय महिला दिवस (सरोजिनी नायडू जयंती)'),
  ImportantDay(2, 20, 'world', 'World Day of Social Justice', 'विश्व सामाजिक न्याय दिवस'),
  ImportantDay(2, 21, 'world', 'International Mother Language Day', 'अंतरराष्ट्रीय मातृभाषा दिवस'),
  ImportantDay(2, 24, 'india', 'Central Excise Day', 'केंद्रीय उत्पाद शुल्क दिवस'),
  ImportantDay(2, 28, 'india', 'National Science Day', 'राष्ट्रीय विज्ञान दिवस'),

  // -------------------------------------------------------------- MARCH
  ImportantDay(3, 1, 'world', 'Zero Discrimination Day', 'शून्य भेदभाव दिवस'),
  ImportantDay(3, 3, 'world', 'World Wildlife Day', 'विश्व वन्यजीव दिवस'),
  ImportantDay(3, 4, 'india', 'National Safety Day', 'राष्ट्रीय सुरक्षा दिवस'),
  ImportantDay(3, 8, 'world', "International Women's Day", 'अंतरराष्ट्रीय महिला दिवस'),
  ImportantDay(3, 15, 'world', 'World Consumer Rights Day', 'विश्व उपभोक्ता अधिकार दिवस'),
  ImportantDay(3, 20, 'world', 'International Day of Happiness', 'अंतरराष्ट्रीय खुशी दिवस'),
  ImportantDay(3, 20, 'world', 'World Sparrow Day', 'विश्व गौरैया दिवस'),
  ImportantDay(3, 21, 'world', 'International Day of Forests', 'अंतरराष्ट्रीय वन दिवस'),
  ImportantDay(3, 22, 'world', 'World Water Day', 'विश्व जल दिवस'),
  ImportantDay(3, 23, 'world', 'World Meteorological Day', 'विश्व मौसम विज्ञान दिवस'),
  ImportantDay(3, 23, 'india', 'Shaheed Diwas (Bhagat Singh, Sukhdev, Rajguru)', 'शहीद दिवस (भगत सिंह, सुखदेव, राजगुरु)'),
  ImportantDay(3, 24, 'world', 'World Tuberculosis (TB) Day', 'विश्व क्षय रोग (टीबी) दिवस'),

  // -------------------------------------------------------------- APRIL
  ImportantDay(4, 5, 'india', 'National Maritime Day', 'राष्ट्रीय समुद्री दिवस'),
  ImportantDay(4, 7, 'world', 'World Health Day', 'विश्व स्वास्थ्य दिवस'),
  ImportantDay(4, 11, 'india', 'National Safe Motherhood Day', 'राष्ट्रीय सुरक्षित मातृत्व दिवस'),
  ImportantDay(4, 14, 'india', 'Ambedkar Jayanti', 'अंबेडकर जयंती'),
  ImportantDay(4, 18, 'world', 'World Heritage Day', 'विश्व धरोहर दिवस'),
  ImportantDay(4, 21, 'india', 'Civil Services Day', 'सिविल सेवा दिवस'),
  ImportantDay(4, 22, 'world', 'World Earth Day', 'विश्व पृथ्वी दिवस'),
  ImportantDay(4, 23, 'world', 'World Book and Copyright Day', 'विश्व पुस्तक एवं कॉपीराइट दिवस'),
  ImportantDay(4, 24, 'india', 'National Panchayati Raj Day', 'राष्ट्रीय पंचायती राज दिवस'),
  ImportantDay(4, 25, 'world', 'World Malaria Day', 'विश्व मलेरिया दिवस'),

  // ---------------------------------------------------------------- MAY
  ImportantDay(5, 1, 'world', 'International Labour Day', 'अंतरराष्ट्रीय श्रमिक दिवस'),
  ImportantDay(5, 1, 'state', 'Maharashtra Day and Gujarat Day', 'महाराष्ट्र दिवस और गुजरात दिवस'),
  ImportantDay(5, 3, 'world', 'World Press Freedom Day', 'विश्व प्रेस स्वतंत्रता दिवस'),
  ImportantDay(5, 8, 'world', 'World Red Cross Day', 'विश्व रेड क्रॉस दिवस'),
  ImportantDay(5, 11, 'india', 'National Technology Day', 'राष्ट्रीय प्रौद्योगिकी दिवस'),
  ImportantDay(5, 12, 'world', 'International Nurses Day', 'अंतरराष्ट्रीय नर्स दिवस'),
  ImportantDay(5, 15, 'world', 'International Day of Families', 'अंतरराष्ट्रीय परिवार दिवस'),
  ImportantDay(5, 17, 'world', 'World Telecommunication Day', 'विश्व दूरसंचार दिवस'),
  ImportantDay(5, 21, 'india', 'Anti-Terrorism Day', 'आतंकवाद विरोधी दिवस'),
  ImportantDay(5, 22, 'world', 'International Day for Biological Diversity', 'अंतरराष्ट्रीय जैव विविधता दिवस'),
  ImportantDay(5, 31, 'world', 'World No Tobacco Day', 'विश्व तंबाकू निषेध दिवस'),

  // --------------------------------------------------------------- JUNE
  ImportantDay(6, 2, 'state', 'Telangana Formation Day', 'तेलंगाना स्थापना दिवस'),
  ImportantDay(6, 5, 'world', 'World Environment Day', 'विश्व पर्यावरण दिवस'),
  ImportantDay(6, 8, 'world', 'World Oceans Day', 'विश्व महासागर दिवस'),
  ImportantDay(6, 12, 'world', 'World Day Against Child Labour', 'विश्व बाल श्रम निषेध दिवस'),
  ImportantDay(6, 14, 'world', 'World Blood Donor Day', 'विश्व रक्तदाता दिवस'),
  ImportantDay(6, 20, 'world', 'World Refugee Day', 'विश्व शरणार्थी दिवस'),
  ImportantDay(6, 21, 'world', 'International Yoga Day', 'अंतरराष्ट्रीय योग दिवस'),
  ImportantDay(6, 26, 'world', 'International Day Against Drug Abuse', 'अंतरराष्ट्रीय नशा निषेध दिवस'),
  ImportantDay(6, 29, 'india', 'National Statistics Day', 'राष्ट्रीय सांख्यिकी दिवस'),

  // --------------------------------------------------------------- JULY
  ImportantDay(7, 1, 'india', "National Doctors' Day", 'राष्ट्रीय चिकित्सक दिवस'),
  ImportantDay(7, 1, 'india', 'GST Day', 'जीएसटी दिवस'),
  ImportantDay(7, 11, 'world', 'World Population Day', 'विश्व जनसंख्या दिवस'),
  ImportantDay(7, 26, 'india', 'Kargil Vijay Diwas', 'कारगिल विजय दिवस'),
  ImportantDay(7, 28, 'world', 'World Nature Conservation Day', 'विश्व प्रकृति संरक्षण दिवस'),
  ImportantDay(7, 28, 'world', 'World Hepatitis Day', 'विश्व हेपेटाइटिस दिवस'),
  ImportantDay(7, 29, 'world', 'International Tiger Day', 'अंतरराष्ट्रीय बाघ दिवस'),

  // ------------------------------------------------------------- AUGUST
  ImportantDay(8, 6, 'world', 'Hiroshima Day', 'हिरोशिमा दिवस'),
  ImportantDay(8, 7, 'india', 'National Handloom Day', 'राष्ट्रीय हथकरघा दिवस'),
  ImportantDay(8, 9, 'india', 'Quit India Movement Day (August Kranti Diwas)', 'भारत छोड़ो आंदोलन दिवस (अगस्त क्रांति दिवस)'),
  ImportantDay(8, 9, 'world', 'Nagasaki Day', 'नागासाकी दिवस'),
  ImportantDay(8, 12, 'world', 'International Youth Day', 'अंतरराष्ट्रीय युवा दिवस'),
  ImportantDay(8, 15, 'india', 'Independence Day', 'स्वतंत्रता दिवस'),
  ImportantDay(8, 19, 'world', 'World Photography Day', 'विश्व फोटोग्राफी दिवस'),
  ImportantDay(8, 20, 'india', 'Sadbhavana Diwas (Rajiv Gandhi Jayanti)', 'सद्भावना दिवस (राजीव गांधी जयंती)'),
  ImportantDay(8, 29, 'india', 'National Sports Day (Major Dhyan Chand Jayanti)', 'राष्ट्रीय खेल दिवस (मेजर ध्यानचंद जयंती)'),

  // ---------------------------------------------------------- SEPTEMBER
  ImportantDay(9, 5, 'india', "Teachers' Day (Dr. S. Radhakrishnan Jayanti)", 'शिक्षक दिवस (डॉ. एस. राधाकृष्णन जयंती)'),
  ImportantDay(9, 8, 'world', 'International Literacy Day', 'अंतरराष्ट्रीय साक्षरता दिवस'),
  ImportantDay(9, 14, 'india', 'Hindi Diwas', 'हिंदी दिवस'),
  ImportantDay(9, 15, 'india', "Engineers' Day (M. Visvesvaraya Jayanti)", 'अभियंता दिवस (एम. विश्वेश्वरैया जयंती)'),
  ImportantDay(9, 15, 'world', 'International Day of Democracy', 'अंतरराष्ट्रीय लोकतंत्र दिवस'),
  ImportantDay(9, 16, 'world', 'World Ozone Day', 'विश्व ओज़ोन दिवस'),
  ImportantDay(9, 21, 'world', 'International Day of Peace', 'अंतरराष्ट्रीय शांति दिवस'),
  ImportantDay(9, 21, 'world', "World Alzheimer's Day", 'विश्व अल्जाइमर दिवस'),
  ImportantDay(9, 27, 'world', 'World Tourism Day', 'विश्व पर्यटन दिवस'),

  // ------------------------------------------------------------ OCTOBER
  ImportantDay(10, 1, 'world', 'International Day of Older Persons', 'अंतरराष्ट्रीय वरिष्ठ नागरिक दिवस'),
  ImportantDay(10, 2, 'india', 'Gandhi Jayanti', 'गांधी जयंती'),
  ImportantDay(10, 2, 'world', 'International Day of Non-Violence', 'अंतरराष्ट्रीय अहिंसा दिवस'),
  ImportantDay(10, 4, 'world', 'World Animal Day', 'विश्व पशु दिवस'),
  ImportantDay(10, 5, 'world', "World Teachers' Day", 'विश्व शिक्षक दिवस'),
  ImportantDay(10, 8, 'india', 'Indian Air Force Day', 'भारतीय वायु सेना दिवस'),
  ImportantDay(10, 9, 'world', 'World Post Day', 'विश्व डाक दिवस'),
  ImportantDay(10, 10, 'world', 'World Mental Health Day', 'विश्व मानसिक स्वास्थ्य दिवस'),
  ImportantDay(10, 11, 'world', 'International Day of the Girl Child', 'अंतरराष्ट्रीय बालिका दिवस'),
  ImportantDay(10, 15, 'world', "World Students' Day (Dr. A. P. J. Abdul Kalam Jayanti)", 'विश्व विद्यार्थी दिवस (डॉ. ए. पी. जे. अब्दुल कलाम जयंती)'),
  ImportantDay(10, 15, 'world', 'Global Handwashing Day', 'वैश्विक हाथ धुलाई दिवस'),
  ImportantDay(10, 16, 'world', 'World Food Day', 'विश्व खाद्य दिवस'),
  ImportantDay(10, 17, 'world', 'International Day for the Eradication of Poverty', 'अंतरराष्ट्रीय गरीबी उन्मूलन दिवस'),
  ImportantDay(10, 24, 'world', 'United Nations Day', 'संयुक्त राष्ट्र दिवस'),
  ImportantDay(10, 31, 'india', 'National Unity Day (Sardar Patel Jayanti)', 'राष्ट्रीय एकता दिवस (सरदार पटेल जयंती)'),

  // ----------------------------------------------------------- NOVEMBER
  ImportantDay(11, 1, 'state', 'Foundation Day: Madhya Pradesh, Chhattisgarh, Karnataka, Kerala, Haryana, Punjab', 'स्थापना दिवस: मध्य प्रदेश, छत्तीसगढ़, कर्नाटक, केरल, हरियाणा, पंजाब'),
  ImportantDay(11, 9, 'india', 'Legal Services Day', 'विधिक सेवा दिवस'),
  ImportantDay(11, 9, 'state', 'Uttarakhand Foundation Day', 'उत्तराखंड स्थापना दिवस'),
  ImportantDay(11, 11, 'india', 'National Education Day (Maulana Azad Jayanti)', 'राष्ट्रीय शिक्षा दिवस (मौलाना आज़ाद जयंती)'),
  ImportantDay(11, 12, 'world', 'World Pneumonia Day', 'विश्व निमोनिया दिवस'),
  ImportantDay(11, 14, 'india', "Children's Day (Jawaharlal Nehru Jayanti)", 'बाल दिवस (जवाहरलाल नेहरू जयंती)'),
  ImportantDay(11, 14, 'world', 'World Diabetes Day', 'विश्व मधुमेह दिवस'),
  ImportantDay(11, 15, 'state', 'Jharkhand Foundation Day', 'झारखंड स्थापना दिवस'),
  ImportantDay(11, 16, 'india', 'National Press Day', 'राष्ट्रीय प्रेस दिवस'),
  ImportantDay(11, 19, 'world', 'World Toilet Day', 'विश्व शौचालय दिवस'),
  ImportantDay(11, 20, 'world', "Universal Children's Day", 'विश्व बाल दिवस'),
  ImportantDay(11, 25, 'world', 'International Day for the Elimination of Violence against Women', 'महिलाओं के विरुद्ध हिंसा उन्मूलन अंतरराष्ट्रीय दिवस'),
  ImportantDay(11, 26, 'india', 'Constitution Day (Samvidhan Diwas)', 'संविधान दिवस'),

  // ----------------------------------------------------------- DECEMBER
  ImportantDay(12, 1, 'world', 'World AIDS Day', 'विश्व एड्स दिवस'),
  ImportantDay(12, 1, 'india', 'BSF Raising Day', 'बीएसएफ स्थापना दिवस'),
  ImportantDay(12, 2, 'india', 'National Pollution Control Day', 'राष्ट्रीय प्रदूषण नियंत्रण दिवस'),
  ImportantDay(12, 3, 'world', 'International Day of Persons with Disabilities', 'अंतरराष्ट्रीय दिव्यांगजन दिवस'),
  ImportantDay(12, 4, 'india', 'Indian Navy Day', 'भारतीय नौसेना दिवस'),
  ImportantDay(12, 5, 'world', 'International Volunteer Day', 'अंतरराष्ट्रीय स्वयंसेवक दिवस'),
  ImportantDay(12, 7, 'india', 'Armed Forces Flag Day', 'सशस्त्र सेना झंडा दिवस'),
  ImportantDay(12, 9, 'world', 'International Anti-Corruption Day', 'अंतरराष्ट्रीय भ्रष्टाचार विरोधी दिवस'),
  ImportantDay(12, 10, 'world', 'Human Rights Day', 'मानवाधिकार दिवस'),
  ImportantDay(12, 11, 'world', 'International Mountain Day', 'अंतरराष्ट्रीय पर्वत दिवस'),
  ImportantDay(12, 14, 'india', 'National Energy Conservation Day', 'राष्ट्रीय ऊर्जा संरक्षण दिवस'),
  ImportantDay(12, 16, 'india', 'Vijay Diwas', 'विजय दिवस'),
  ImportantDay(12, 18, 'india', 'Minorities Rights Day', 'अल्पसंख्यक अधिकार दिवस'),
  ImportantDay(12, 18, 'world', 'International Migrants Day', 'अंतरराष्ट्रीय प्रवासी दिवस'),
  ImportantDay(12, 19, 'state', 'Goa Liberation Day', 'गोवा मुक्ति दिवस'),
  ImportantDay(12, 22, 'india', 'National Mathematics Day (Srinivasa Ramanujan Jayanti)', 'राष्ट्रीय गणित दिवस (श्रीनिवास रामानुजन जयंती)'),
  ImportantDay(12, 23, 'india', 'Kisan Diwas (Chaudhary Charan Singh Jayanti)', 'किसान दिवस (चौधरी चरण सिंह जयंती)'),
  ImportantDay(12, 24, 'india', 'National Consumer Rights Day', 'राष्ट्रीय उपभोक्ता अधिकार दिवस'),
  ImportantDay(12, 25, 'india', 'Good Governance Day (Atal Bihari Vajpayee Jayanti)', 'सुशासन दिवस (अटल बिहारी वाजपेयी जयंती)'),
];
