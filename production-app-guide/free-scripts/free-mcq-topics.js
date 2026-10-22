/**
 * Syllabus topics for the Static GK / General Science / General Studies sets.
 *
 * These are only TOPIC NAMES (our own outline, following the UPPCS Prelims GS-I syllabus:
 * history and national movement, geography, polity and governance, economic and social
 * development, environment / ecology / climate change, general science, "with special
 * reference to Uttar Pradesh"). No text from any website or book is stored or copied:
 * Gemini writes original questions on these topics and every question is fact-checked twice.
 *
 * `exams`: the group is used only for these exams (omit = every exam).
 */

const TOPICS_PER_SET = 10;

const POOLS = {
  gk: [
    {
      label: "Ancient and medieval India",
      topics: ["Indus Valley Civilisation", "Vedic period", "Maurya Empire and Ashoka", "Gupta Empire", "Harsha and the Pushyabhuti dynasty", "Chola dynasty", "Delhi Sultanate", "Mughal Empire and Akbar", "Sher Shah Suri and his reforms", "Maratha Empire", "Vijayanagara Empire", "Buddhism and Jainism", "Bhakti and Sufi movements", "Battles of Panipat", "Battle of Haldighati"],
    },
    {
      label: "Modern India and the national movement",
      topics: ["Battle of Plassey and Battle of Buxar", "Revolt of 1857", "Foundation and early phase of the Indian National Congress", "Swadeshi movement and the Partition of Bengal", "Jallianwala Bagh massacre", "Non-Cooperation Movement", "Civil Disobedience Movement and Dandi March", "Quit India Movement", "Champaran Satyagraha", "Cabinet Mission and Indian Independence Act 1947", "Regulating Act 1773 to Government of India Act 1935", "Permanent Settlement and land revenue systems", "Subhas Chandra Bose and the INA", "Revolutionaries: Bhagat Singh, Chandrashekhar Azad, Kakori and Chauri Chaura", "Social reform movements of the 19th century"],
    },
    {
      label: "Geography of India and the world",
      topics: ["Physiography of India: Himalayas, Plains, Plateau, Coasts", "Western Ghats and Eastern Ghats", "Thar Desert and the Indo-Gangetic Plain", "Climate and monsoon of India", "Major rivers of India and their tributaries", "Lakes and waterfalls of India", "Soils of India", "Natural vegetation of India", "Minerals and power resources of India", "Agriculture and major crops of India", "Major ports and transport of India", "Latitudes, longitudes and time zones", "Continents, oceans and major world rivers", "Plate tectonics, earthquakes and volcanoes", "Major deserts, mountains and straits of the world"],
    },
    {
      label: "Art, culture, awards and sports",
      topics: ["Indian classical dances", "Indian classical music and instruments", "Folk dances and festivals of India", "Architecture: temple styles and Indo-Islamic monuments", "UNESCO World Heritage Sites in India", "Languages and scripts of India", "National symbols of India", "Bharat Ratna and Padma awards", "Jnanpith and Sahitya Akademi awards", "Sports awards of India", "Olympic Games and Commonwealth Games", "Famous books and authors", "Important days and observances", "Fairs and festivals of India"],
    },
    {
      label: "Uttar Pradesh",
      exams: ["up_state"],
      topics: ["History of Uttar Pradesh: Awadh and 1857 in UP", "Geography of Uttar Pradesh: regions and rivers", "Rivers of Uttar Pradesh: Ganga, Yamuna, Gomti, Ghaghara, Chambal", "Cities of Uttar Pradesh: Lucknow, Varanasi, Prayagraj, Agra, Mathura, Ayodhya", "Monuments and tourism in Uttar Pradesh", "Fairs, festivals and handicrafts of Uttar Pradesh", "National parks and wildlife sanctuaries of Uttar Pradesh", "Universities and education in Uttar Pradesh", "Folk music, dance and literature of Uttar Pradesh", "Freedom fighters of Uttar Pradesh"],
    },
  ],

  science: [
    {
      label: "Physics",
      topics: ["Newton's laws of motion and gravitation", "Work, energy and power", "Light: reflection, refraction and lenses", "Sound and the Doppler effect", "Electric current, Ohm's law and circuits", "Magnetism and electromagnetic induction", "Heat and temperature", "Pressure, Archimedes' principle and Bernoulli's principle", "Electromagnetic spectrum", "Nuclear fission and fusion", "Semiconductors, lasers and optical fibre"],
    },
    {
      label: "Chemistry",
      topics: ["Periodic table and periodic properties", "Acids, bases and salts; pH", "Chemical bonding", "Metals, non-metals and alloys", "Carbon and its compounds; allotropes", "Fuels: petroleum, LPG, CNG and biofuels", "Corrosion and rusting", "Polymers, plastics and fertilizers", "Soaps, detergents and hard water", "Ozone layer and atmospheric chemistry", "Isotopes and radioactivity"],
    },
    {
      label: "Biology and human health",
      topics: ["Human digestive system and nutrition", "Human circulatory system and blood", "Human respiratory and excretory systems", "Nervous and endocrine systems", "Vitamins, minerals and deficiency diseases", "Cell structure and cell division", "Photosynthesis and plant physiology", "Genetics, DNA and heredity", "Communicable diseases: causes and vaccines", "Non-communicable and lifestyle diseases", "Classification of plants and animals", "Immunity and vaccination"],
    },
    {
      label: "Space, defence and everyday technology",
      topics: ["ISRO and Indian satellites", "Chandrayaan, Mangalyaan and Aditya-L1 missions", "Gaganyaan and the Indian human spaceflight programme", "India's missiles and DRDO", "Satellite types and navigation systems (GPS, NavIC)", "Artificial intelligence, internet and 5G basics", "Nanotechnology and biotechnology basics", "Genetically modified organisms", "Everyday science: household devices and materials"],
    },
  ],

  gs: [
    {
      label: "Indian polity and governance",
      topics: ["Making of the Constitution and the Preamble", "Fundamental Rights", "Directive Principles and Fundamental Duties", "Union Parliament: Lok Sabha and Rajya Sabha", "President, Vice-President and Prime Minister", "Supreme Court and High Courts", "Election Commission, CAG and UPSC", "Finance Commission and NITI Aayog", "Panchayati Raj and the 73rd and 74th Amendments", "Important Constitutional Amendments", "Emergency provisions", "Right to Information Act and Lokpal", "Basic structure doctrine and landmark cases", "Centre-State relations", "State Legislature, Governor and Chief Minister"],
    },
    {
      label: "Economic and social development",
      topics: ["Five-Year Plans and NITI Aayog", "Union Budget basics and types of taxes", "GST and the tax system", "Reserve Bank of India and monetary policy basics", "Banking system and financial institutions", "SEBI, stock market basics and NABARD", "Inflation, GDP and basic economic terms", "Green Revolution and White Revolution", "Poverty, unemployment and human development", "Census and demography of India", "Major government schemes (Jan Dhan, MGNREGA, Ayushman Bharat, Swachh Bharat)", "Digital India, UPI and financial inclusion", "Education policy and social sector schemes"],
    },
    {
      label: "Environment, ecology, biodiversity and climate change",
      topics: ["Ecosystem, food chain and food web", "Biodiversity and biodiversity hotspots", "National parks, biosphere reserves and Ramsar sites of India", "Project Tiger and wildlife conservation laws", "Climate change and global warming", "Greenhouse gases and the ozone layer", "International environmental agreements: Kyoto, Paris, Montreal, Ramsar", "Environmental laws and the National Green Tribunal", "Pollution: air, water and soil", "Renewable energy and the International Solar Alliance", "Environmental movements of India", "Wetlands, mangroves and coral reefs"],
    },
    {
      label: "International organisations",
      topics: ["United Nations and its agencies", "World Bank, IMF and WTO", "BRICS, G20 and SCO", "SAARC and ASEAN", "NATO and OPEC", "Quad and other groupings involving India", "Non-Aligned Movement and the Commonwealth", "Major international treaties and summits"],
    },
    {
      label: "Uttar Pradesh governance and economy",
      exams: ["up_state"],
      topics: ["Uttar Pradesh Legislature, Governor and Chief Minister", "Uttar Pradesh economy: agriculture and industry", "Demographics and districts of Uttar Pradesh", "Major government schemes of Uttar Pradesh", "Allahabad High Court and judicial set-up of Uttar Pradesh", "Local self-government in Uttar Pradesh", "Transport and expressways of Uttar Pradesh", "Uttar Pradesh Public Service Commission and recruitment bodies"],
    },
  ],
};

// ---------------------------------------------------------------- helpers

/** Small deterministic random generator, so the same exam+subject+month always picks the same topics. */
function seededRandom(seedText) {
  let h = 1779033703 ^ seedText.length;
  for (let i = 0; i < seedText.length; i++) {
    h = Math.imul(h ^ seedText.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = (h ^ (h >>> 16)) >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffled(arr, rnd) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** The topics of one set: round-robin over the topic groups, so every set spreads over the syllabus. */
function pickTopics({ subjectId, examId, monthKey, n = TOPICS_PER_SET }) {
  const groups = (POOLS[subjectId] || []).filter((g) => !g.exams || g.exams.includes(examId));
  const rnd = seededRandom(`${examId}|${subjectId}|${monthKey}`);
  const lists = shuffled(groups, rnd).map((g) => shuffled(g.topics, rnd));
  const out = [];
  for (let round = 0; out.length < n; round++) {
    let any = false;
    for (const list of lists) {
      if (round < list.length) {
        any = true;
        out.push(list[round]);
        if (out.length >= n) break;
      }
    }
    if (!any) break;
  }
  return out;
}

module.exports = { POOLS, TOPICS_PER_SET, pickTopics, seededRandom };
