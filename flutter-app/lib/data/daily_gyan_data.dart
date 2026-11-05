// =============================================================================
//  "Aaj ka Gyaan" ka content (Home screen):
//
//  1) Word of the Day  - Banking PO (IBPS PO / SBI PO) English vocabulary,
//                        har word ke saath Hindi meaning, Synonyms aur Antonyms.
//  2) Did you know?    - Hard-level facts jo SSC CGL / RRB NTPC / UPSSSC /
//                        AHC RO / UPPSC ke syllabus se aate hain:
//                        General Science, General Studies (Polity, History,
//                        Geography, Economy), Static GK aur UP GK.
//
//  Roz date ke hisaab se ek-ek entry badalti hai (list ki lambai ke hisaab se
//  cycle). Content app ke andar bundled hai: internet / Firestore ki zaroorat
//  nahi, Firestore ko 0 reads / 0 writes.
//
//  NAYA CONTENT JODNE KE NIYAM (Dart ki galti se bachne ke liye):
//   - Har text DOUBLE quotes "..." me likho. Text ke andar double quote (")
//     mat likho; English me ‘ ’ (curly quotes) use karo.
//   - Text me dollar sign mat likho.
//   - GyanFact ka pehla field topic-key hai. Sirf ye keys chalti hain:
//     Science, Polity, History, Geography, Economy, StaticGK, UPGK.
// =============================================================================

class GyanWord {
  final String word;
  final String pos; // adj. / v. / n.
  final String hi; // Hindi meaning
  final String en; // English meaning
  final String example;
  final List<String> syn; // Synonyms
  final List<String> ant; // Antonyms
  const GyanWord(this.word, this.pos, this.hi, this.en, this.example, this.syn, this.ant);
}

class GyanFact {
  final String topic; // Science / Polity / History / Geography / Economy / StaticGK / UPGK
  final String en;
  final String hi;
  const GyanFact(this.topic, this.en, this.hi);
}

const List<GyanWord> kGyanWords = [
  GyanWord("Abate", "v.", "कम होना / घटना", "To become less intense", "The storm began to abate by evening.", ["Subside", "Diminish", "Ebb"], ["Intensify", "Escalate", "Swell"]),
  GyanWord("Aberration", "n.", "विपथन / सामान्य से हटकर होना", "A departure from what is normal", "The sudden loss was an aberration in an otherwise profitable year.", ["Anomaly", "Deviation", "Irregularity"], ["Norm", "Conformity", "Regularity"]),
  GyanWord("Acrimony", "n.", "कटुता", "Bitterness in speech or manner", "The meeting ended in acrimony over the budget.", ["Bitterness", "Rancour", "Hostility"], ["Goodwill", "Cordiality", "Harmony"]),
  GyanWord("Adamant", "adj.", "अड़ियल / अटल", "Refusing to change one's mind", "The manager was adamant about the deadline.", ["Unyielding", "Resolute", "Inflexible"], ["Flexible", "Yielding", "Pliant"]),
  GyanWord("Alleviate", "v.", "राहत देना / कम करना", "To make suffering or a problem less severe", "The new scheme will alleviate the farmers' debt burden.", ["Relieve", "Ease", "Mitigate"], ["Aggravate", "Worsen", "Intensify"]),
  GyanWord("Altruistic", "adj.", "परोपकारी", "Showing selfless concern for others", "Her altruistic donation funded a village school.", ["Selfless", "Charitable", "Unselfish"], ["Selfish", "Greedy", "Self-centred"]),
  GyanWord("Ambiguous", "adj.", "अस्पष्ट / दो अर्थ वाला", "Open to more than one meaning", "The clause in the loan agreement was ambiguous.", ["Vague", "Equivocal", "Unclear"], ["Clear", "Explicit", "Definite"]),
  GyanWord("Ameliorate", "v.", "सुधारना", "To make a bad situation better", "Policy changes helped ameliorate the credit crunch.", ["Improve", "Enhance", "Better"], ["Worsen", "Aggravate", "Deteriorate"]),
  GyanWord("Arduous", "adj.", "कठिन / श्रमसाध्य", "Needing great effort and stamina", "Preparing for the exam was an arduous task.", ["Strenuous", "Laborious", "Gruelling"], ["Easy", "Effortless", "Simple"]),
  GyanWord("Austere", "adj.", "कठोर / सादा", "Strict and plain, without luxury", "He led an austere life despite his wealth.", ["Stern", "Spartan", "Severe"], ["Luxurious", "Lavish", "Indulgent"]),
  GyanWord("Belligerent", "adj.", "झगड़ालू", "Hostile and eager to fight", "The belligerent customer shouted at the cashier.", ["Hostile", "Aggressive", "Combative"], ["Peaceful", "Amiable", "Friendly"]),
  GyanWord("Benevolent", "adj.", "परोपकारी / दयालु", "Kind and generous", "A benevolent trust runs free coaching centres.", ["Kind", "Generous", "Charitable"], ["Malevolent", "Cruel", "Unkind"]),
  GyanWord("Bolster", "v.", "मज़बूत करना / सहारा देना", "To support or strengthen", "The rate cut will bolster economic growth.", ["Strengthen", "Reinforce", "Support"], ["Weaken", "Undermine", "Undercut"]),
  GyanWord("Candid", "adj.", "स्पष्टवादी", "Honest and straightforward", "She gave a candid opinion about the plan.", ["Frank", "Open", "Forthright"], ["Evasive", "Guarded", "Secretive"]),
  GyanWord("Capricious", "adj.", "सनकी / अस्थिर स्वभाव का", "Changing mood or behaviour suddenly", "The capricious market made investors nervous.", ["Fickle", "Whimsical", "Erratic"], ["Steady", "Consistent", "Stable"]),
  GyanWord("Censure", "v.", "निंदा करना", "To criticise formally and severely", "The committee censured the bank for poor audits.", ["Condemn", "Rebuke", "Reprimand"], ["Praise", "Commend", "Applaud"]),
  GyanWord("Circumspect", "adj.", "सतर्क / सोच-समझकर चलने वाला", "Careful to consider risks before acting", "Be circumspect while signing financial documents.", ["Cautious", "Prudent", "Wary"], ["Reckless", "Rash", "Careless"]),
  GyanWord("Clandestine", "adj.", "गुप्त", "Kept secret, often because it is illegal", "The police busted a clandestine money-lending ring.", ["Secret", "Covert", "Furtive"], ["Open", "Overt", "Public"]),
  GyanWord("Cogent", "adj.", "सशक्त / तर्कसंगत", "Clear, logical and convincing", "She made a cogent argument for the merger.", ["Convincing", "Compelling", "Persuasive"], ["Unconvincing", "Weak", "Feeble"]),
  GyanWord("Condone", "v.", "माफ़ करना / अनदेखा करना", "To accept or overlook wrong behaviour", "The bank does not condone corruption.", ["Overlook", "Excuse", "Pardon"], ["Condemn", "Censure", "Disapprove"]),
  GyanWord("Corroborate", "v.", "पुष्टि करना", "To confirm with additional evidence", "Bank records corroborated his statement.", ["Confirm", "Verify", "Substantiate"], ["Contradict", "Refute", "Disprove"]),
  GyanWord("Dearth", "n.", "कमी / अभाव", "A scarcity or lack of something", "There is a dearth of skilled clerks in the town.", ["Scarcity", "Shortage", "Paucity"], ["Abundance", "Plenty", "Surplus"]),
  GyanWord("Debacle", "n.", "भारी विफलता", "A sudden and complete failure", "The merger turned into a financial debacle.", ["Fiasco", "Collapse", "Disaster"], ["Triumph", "Success", "Victory"]),
  GyanWord("Deference", "n.", "सम्मान / आदर", "Polite respect for someone's opinion", "He spoke with deference to the senior officer.", ["Respect", "Regard", "Homage"], ["Disrespect", "Contempt", "Disregard"]),
  GyanWord("Despondent", "adj.", "निराश", "Feeling hopeless and dejected", "He was despondent after missing the cut-off by one mark.", ["Dejected", "Disheartened", "Gloomy"], ["Cheerful", "Hopeful", "Elated"]),
  GyanWord("Diligent", "adj.", "मेहनती", "Hard-working and careful", "A diligent student revises every day.", ["Hardworking", "Industrious", "Assiduous"], ["Lazy", "Idle", "Negligent"]),
  GyanWord("Disparage", "v.", "तिरस्कार करना / नीचा दिखाना", "To speak of someone as having little value", "Do not disparage other candidates' efforts.", ["Belittle", "Denigrate", "Deprecate"], ["Praise", "Laud", "Extol"]),
  GyanWord("Eclectic", "adj.", "विविध स्रोतों से चुना हुआ", "Drawn from a wide variety of sources", "She has an eclectic reading list for her exam.", ["Diverse", "Varied", "Wide-ranging"], ["Narrow", "Limited", "Uniform"]),
  GyanWord("Elusive", "adj.", "पकड़ से बाहर", "Hard to find, catch or achieve", "A perfect score remained elusive.", ["Evasive", "Slippery", "Intangible"], ["Obvious", "Evident", "Noticeable"]),
  GyanWord("Eloquent", "adj.", "वाक्पटु", "Fluent and persuasive in speech", "His eloquent speech moved the crowd.", ["Articulate", "Expressive", "Fluent"], ["Inarticulate", "Tongue-tied", "Hesitant"]),
  GyanWord("Ephemeral", "adj.", "क्षणभंगुर", "Lasting for a very short time", "The gains in the stock were ephemeral.", ["Transient", "Fleeting", "Short-lived"], ["Permanent", "Eternal", "Lasting"]),
  GyanWord("Equanimity", "n.", "मानसिक संतुलन / शांतचित्तता", "Calmness in a difficult situation", "She faced the interview with equanimity.", ["Composure", "Calmness", "Poise"], ["Agitation", "Anxiety", "Turmoil"]),
  GyanWord("Erudite", "adj.", "विद्वान", "Having or showing great learning", "The erudite professor guided many aspirants.", ["Learned", "Scholarly", "Knowledgeable"], ["Ignorant", "Illiterate", "Unlettered"]),
  GyanWord("Exacerbate", "v.", "और बिगाड़ना / भड़काना", "To make a problem worse", "High inflation will exacerbate the crisis.", ["Aggravate", "Worsen", "Intensify"], ["Alleviate", "Soothe", "Improve"]),
  GyanWord("Exonerate", "v.", "दोषमुक्त करना", "To clear someone from blame", "The audit exonerated the cashier.", ["Absolve", "Acquit", "Clear"], ["Convict", "Blame", "Incriminate"]),
  GyanWord("Fallacy", "n.", "भ्रांति / तर्कदोष", "A mistaken belief based on faulty reasoning", "It is a fallacy that expensive coaching alone guarantees success.", ["Misconception", "Delusion", "Myth"], ["Truth", "Fact", "Reality"]),
  GyanWord("Fastidious", "adj.", "नुक्ताचीं / बहुत सावधान", "Very attentive to accuracy and detail", "The fastidious clerk rechecked every entry.", ["Meticulous", "Particular", "Finicky"], ["Careless", "Sloppy", "Slapdash"]),
  GyanWord("Feasible", "adj.", "संभव / व्यावहारिक", "Possible and practical to do", "The committee found the plan financially feasible.", ["Viable", "Practicable", "Workable"], ["Impractical", "Unworkable", "Unviable"]),
  GyanWord("Fervent", "adj.", "उत्कट / जोशीला", "Showing intense and sincere feeling", "He made a fervent appeal for donations.", ["Ardent", "Passionate", "Zealous"], ["Apathetic", "Indifferent", "Cool"]),
  GyanWord("Flamboyant", "adj.", "भड़कीला", "Showy and attracting attention", "The flamboyant tycoon arrived in a gold car.", ["Showy", "Ostentatious", "Flashy"], ["Modest", "Subdued", "Restrained"]),
  GyanWord("Fortuitous", "adj.", "संयोगवश / आकस्मिक", "Happening by chance, often luckily", "Their meeting at the bank was entirely fortuitous.", ["Accidental", "Chance", "Lucky"], ["Planned", "Intentional", "Deliberate"]),
  GyanWord("Frugal", "adj.", "मितव्ययी", "Careful about spending money", "They led a frugal life.", ["Thrifty", "Economical", "Sparing"], ["Extravagant", "Wasteful", "Lavish"]),
  GyanWord("Futile", "adj.", "व्यर्थ", "Producing no useful result", "Arguing with the examiner was futile.", ["Useless", "Fruitless", "Vain"], ["Fruitful", "Productive", "Effective"]),
  GyanWord("Garrulous", "adj.", "बातूनी", "Talking too much about trivial things", "The garrulous neighbour kept the clerk talking for an hour.", ["Talkative", "Loquacious", "Chatty"], ["Taciturn", "Reticent", "Quiet"]),
  GyanWord("Haphazard", "adj.", "अव्यवस्थित", "Lacking order or planning", "Haphazard revision rarely clears the exam.", ["Random", "Disorganised", "Careless"], ["Systematic", "Orderly", "Methodical"]),
  GyanWord("Hindrance", "n.", "बाधा", "A thing that makes progress difficult", "Fear of failure is the biggest hindrance to success.", ["Obstacle", "Impediment", "Barrier"], ["Help", "Aid", "Assistance"]),
  GyanWord("Hypocrisy", "n.", "पाखंड", "Saying one thing but doing another", "Preaching honesty while cheating is hypocrisy.", ["Insincerity", "Duplicity", "Pretence"], ["Sincerity", "Honesty", "Integrity"]),
  GyanWord("Impartial", "adj.", "निष्पक्ष", "Treating all sides equally", "The panel must remain impartial while selecting candidates.", ["Unbiased", "Neutral", "Fair"], ["Biased", "Partial", "Prejudiced"]),
  GyanWord("Imminent", "adj.", "निकट / आसन्न", "About to happen", "The exam is imminent, so start revising.", ["Impending", "Looming", "Approaching"], ["Distant", "Remote", "Far-off"]),
  GyanWord("Impeccable", "adj.", "बेदाग / त्रुटिहीन", "Perfect, without any fault", "Her accounts were maintained in an impeccable manner.", ["Flawless", "Faultless", "Perfect"], ["Flawed", "Faulty", "Imperfect"]),
  GyanWord("Impetuous", "adj.", "उतावला / आवेगी", "Acting quickly without thinking", "An impetuous decision to invest cost him dearly.", ["Impulsive", "Rash", "Hasty"], ["Cautious", "Deliberate", "Careful"]),
  GyanWord("Indigent", "adj.", "निर्धन", "Very poor", "The scheme gives loans to indigent families.", ["Poor", "Needy", "Destitute"], ["Affluent", "Wealthy", "Rich"]),
  GyanWord("Inept", "adj.", "अकुशल / अयोग्य", "Having no skill; clumsy", "An inept manager can ruin a good team.", ["Unskilled", "Incompetent", "Clumsy"], ["Skilful", "Adept", "Competent"]),
  GyanWord("Innate", "adj.", "जन्मजात", "Inborn; present from birth", "She has an innate talent for mathematics.", ["Inborn", "Inherent", "Natural"], ["Acquired", "Learned", "Extrinsic"]),
  GyanWord("Insolvent", "adj.", "दिवालिया", "Unable to pay one's debts", "The insolvent firm was taken over by its lender.", ["Bankrupt", "Broke", "Ruined"], ["Solvent", "Wealthy", "Prosperous"]),
  GyanWord("Intrepid", "adj.", "निडर", "Fearless and adventurous", "The intrepid officer led the rescue team.", ["Fearless", "Bold", "Courageous"], ["Timid", "Fearful", "Cowardly"]),
  GyanWord("Lethargic", "adj.", "सुस्त", "Lacking energy and enthusiasm", "The heat made everyone lethargic.", ["Sluggish", "Listless", "Lazy"], ["Energetic", "Active", "Lively"]),
  GyanWord("Loquacious", "adj.", "वाचाल / बहुत बोलने वाला", "Tending to talk a great deal", "The loquacious guide narrated every detail of the fort.", ["Talkative", "Garrulous", "Voluble"], ["Reticent", "Taciturn", "Reserved"]),
  GyanWord("Lucrative", "adj.", "लाभदायक", "Producing a great deal of profit", "Banking is a lucrative career for many graduates.", ["Profitable", "Gainful", "Remunerative"], ["Unprofitable", "Unrewarding", "Loss-making"]),
  GyanWord("Magnanimous", "adj.", "उदार / महान हृदय वाला", "Generous and forgiving", "The magnanimous owner waived the pending dues.", ["Generous", "Noble", "Big-hearted"], ["Petty", "Mean", "Selfish"]),
  GyanWord("Mandatory", "adj.", "अनिवार्य", "Required by law or rule", "KYC is mandatory for opening a bank account.", ["Compulsory", "Obligatory", "Required"], ["Optional", "Voluntary", "Discretionary"]),
  GyanWord("Meticulous", "adj.", "बारीकी से सावधान", "Very careful about details", "He is meticulous about his notes.", ["Careful", "Precise", "Thorough"], ["Careless", "Negligent", "Sloppy"]),
  GyanWord("Mitigate", "v.", "कम करना / हल्का करना", "To make something less severe", "Insurance helps mitigate financial risk.", ["Lessen", "Alleviate", "Reduce"], ["Aggravate", "Intensify", "Worsen"]),
  GyanWord("Mollify", "v.", "शांत करना / मनाना", "To calm someone who is angry", "The manager tried to mollify the angry customer.", ["Pacify", "Appease", "Soothe"], ["Provoke", "Irritate", "Enrage"]),
  GyanWord("Mundane", "adj.", "साधारण / नीरस", "Ordinary and lacking excitement", "He was tired of mundane tasks.", ["Ordinary", "Routine", "Banal"], ["Extraordinary", "Unusual", "Exceptional"]),
  GyanWord("Naive", "adj.", "भोला", "Lacking experience or judgement", "It is naive to trust every investment tip.", ["Gullible", "Innocent", "Unsophisticated"], ["Shrewd", "Worldly", "Sophisticated"]),
  GyanWord("Nefarious", "adj.", "दुष्ट / घृणित", "Wicked or criminal", "Police uncovered a nefarious plot to cheat depositors.", ["Wicked", "Villainous", "Heinous"], ["Virtuous", "Honourable", "Noble"]),
  GyanWord("Negligent", "adj.", "लापरवाह", "Failing to take proper care", "The bank was negligent in verifying the documents.", ["Careless", "Remiss", "Lax"], ["Careful", "Diligent", "Attentive"]),
  GyanWord("Notorious", "adj.", "कुख्यात", "Famous for something bad", "The area was notorious for cyber fraud.", ["Infamous", "Disreputable", "Ill-famed"], ["Reputable", "Esteemed", "Honourable"]),
  GyanWord("Obfuscate", "v.", "उलझाना / धुंधला करना", "To make something unclear or confusing", "The complex terms seemed to obfuscate the real charges.", ["Obscure", "Confuse", "Muddle"], ["Clarify", "Illuminate", "Elucidate"]),
  GyanWord("Obsolete", "adj.", "अप्रचलित", "No longer in use", "Floppy disks are now obsolete.", ["Outdated", "Archaic", "Outmoded"], ["Modern", "Current", "Up-to-date"]),
  GyanWord("Ostentatious", "adj.", "दिखावटी", "Designed to impress; showy", "The ostentatious wedding drew public criticism.", ["Showy", "Pretentious", "Flashy"], ["Modest", "Humble", "Unpretentious"]),
  GyanWord("Paramount", "adj.", "सर्वोपरि", "More important than anything else", "Customer trust is paramount for a bank.", ["Supreme", "Chief", "Foremost"], ["Minor", "Secondary", "Trivial"]),
  GyanWord("Penury", "n.", "घोर निर्धनता", "Extreme poverty", "He rose from penury to become a bank manager.", ["Poverty", "Destitution", "Indigence"], ["Wealth", "Affluence", "Prosperity"]),
  GyanWord("Perfunctory", "adj.", "ऊपरी / रस्मी", "Done with little effort or interest", "The officer gave only a perfunctory glance at the file.", ["Cursory", "Superficial", "Casual"], ["Thorough", "Painstaking", "Diligent"]),
  GyanWord("Pernicious", "adj.", "हानिकारक / घातक", "Having a harmful effect, often gradually", "Corruption has a pernicious effect on the economy.", ["Harmful", "Destructive", "Deadly"], ["Beneficial", "Harmless", "Helpful"]),
  GyanWord("Pertinent", "adj.", "प्रासंगिक", "Relevant to the matter in hand", "Answer only pertinent questions in the interview.", ["Relevant", "Apt", "Applicable"], ["Irrelevant", "Unrelated", "Inapplicable"]),
  GyanWord("Placid", "adj.", "शांत", "Calm and not easily disturbed", "The placid lake reflected the hills.", ["Calm", "Tranquil", "Serene"], ["Turbulent", "Agitated", "Stormy"]),
  GyanWord("Plausible", "adj.", "विश्वसनीय / संभावित", "Seeming reasonable or believable", "His explanation sounded plausible.", ["Credible", "Believable", "Reasonable"], ["Implausible", "Unbelievable", "Far-fetched"]),
  GyanWord("Pragmatic", "adj.", "व्यावहारिक", "Practical rather than theoretical", "We need a pragmatic solution.", ["Practical", "Realistic", "Sensible"], ["Impractical", "Idealistic", "Unrealistic"]),
  GyanWord("Precarious", "adj.", "अनिश्चित / जोखिम भरा", "Not secure; likely to fall or fail", "The firm's finances were in a precarious state.", ["Risky", "Unstable", "Perilous"], ["Secure", "Safe", "Stable"]),
  GyanWord("Procrastinate", "v.", "टालमटोल करना", "To delay doing something", "Do not procrastinate; start revising today.", ["Delay", "Postpone", "Dawdle"], ["Hasten", "Expedite", "Hurry"]),
  GyanWord("Prodigal", "adj.", "फ़िज़ूलख़र्च", "Spending money recklessly", "The prodigal heir wasted his inheritance.", ["Wasteful", "Extravagant", "Spendthrift"], ["Thrifty", "Frugal", "Economical"]),
  GyanWord("Prolific", "adj.", "अत्यधिक उत्पादक / रचनाशील", "Producing a great deal", "She is a prolific writer of exam guides.", ["Productive", "Fertile", "Abundant"], ["Unproductive", "Barren", "Sterile"]),
  GyanWord("Prudent", "adj.", "विवेकी / समझदार", "Acting with care and good judgement", "It is prudent to save some money.", ["Wise", "Judicious", "Cautious"], ["Imprudent", "Foolish", "Reckless"]),
  GyanWord("Recalcitrant", "adj.", "अड़ियल / अवज्ञाकारी", "Stubbornly refusing to obey rules", "The recalcitrant borrower ignored every notice.", ["Stubborn", "Unruly", "Defiant"], ["Obedient", "Compliant", "Docile"]),
  GyanWord("Rectify", "v.", "सुधारना / ठीक करना", "To put right; to correct", "The bank promised to rectify the error.", ["Correct", "Amend", "Remedy"], ["Damage", "Worsen", "Spoil"]),
  GyanWord("Redundant", "adj.", "अनावश्यक / फ़ालतू", "Not needed; superfluous", "Several redundant posts were abolished.", ["Superfluous", "Surplus", "Unnecessary"], ["Essential", "Necessary", "Needed"]),
  GyanWord("Refute", "v.", "खंडन करना", "To prove a statement to be wrong", "The data refuted the claim.", ["Disprove", "Rebut", "Counter"], ["Confirm", "Prove", "Support"]),
  GyanWord("Reticent", "adj.", "मितभाषी / संकोची", "Not revealing thoughts or feelings easily", "She was reticent about her salary.", ["Reserved", "Taciturn", "Silent"], ["Talkative", "Outspoken", "Communicative"]),
  GyanWord("Salient", "adj.", "प्रमुख / उल्लेखनीय", "Most noticeable or important", "Note the salient features of the new policy.", ["Prominent", "Notable", "Striking"], ["Insignificant", "Minor", "Trivial"]),
  GyanWord("Scrupulous", "adj.", "ईमानदार / सावधान", "Careful, honest and principled", "He is scrupulous about repaying every loan on time.", ["Honest", "Principled", "Conscientious"], ["Unscrupulous", "Careless", "Dishonest"]),
  GyanWord("Stagnant", "adj.", "ठहरा हुआ / निष्क्रिय", "Not growing or developing", "The economy remained stagnant for two quarters.", ["Static", "Sluggish", "Inactive"], ["Dynamic", "Flourishing", "Active"]),
  GyanWord("Superfluous", "adj.", "फ़ालतू / अनावश्यक", "More than is needed", "Delete the superfluous words from your answer.", ["Unnecessary", "Excess", "Surplus"], ["Essential", "Necessary", "Vital"]),
  GyanWord("Surreptitious", "adj.", "चोरी-छिपे", "Done secretly to avoid notice", "He took a surreptitious glance at the answer sheet.", ["Stealthy", "Secret", "Furtive"], ["Open", "Blatant", "Overt"]),
  GyanWord("Tangible", "adj.", "मूर्त / ठोस", "Able to be touched or clearly seen", "The scheme produced tangible benefits for farmers.", ["Concrete", "Palpable", "Real"], ["Intangible", "Abstract", "Imaginary"]),
  GyanWord("Tenacious", "adj.", "दृढ़ / अडिग", "Holding firmly to a goal", "Her tenacious effort finally paid off.", ["Persistent", "Determined", "Resolute"], ["Weak", "Yielding", "Irresolute"]),
  GyanWord("Transient", "adj.", "क्षणिक / अस्थायी", "Lasting only a short time", "Transient workers moved from town to town.", ["Temporary", "Fleeting", "Passing"], ["Permanent", "Lasting", "Enduring"]),
  GyanWord("Ubiquitous", "adj.", "सर्वव्यापी", "Found everywhere", "Smartphones are ubiquitous today.", ["Omnipresent", "Pervasive", "Universal"], ["Rare", "Scarce", "Limited"]),
  GyanWord("Venerable", "adj.", "आदरणीय", "Deserving great respect because of age or wisdom", "The venerable teacher was honoured by all.", ["Revered", "Respected", "Esteemed"], ["Despised", "Contemptible", "Disreputable"]),
  GyanWord("Verbose", "adj.", "वाचाल / शब्दबहुल", "Using more words than needed", "His verbose answer confused everyone.", ["Wordy", "Long-winded", "Prolix"], ["Concise", "Terse", "Succinct"]),
  GyanWord("Volatile", "adj.", "अस्थिर / उतार-चढ़ाव वाला", "Likely to change suddenly", "The stock market is highly volatile today.", ["Unstable", "Erratic", "Fickle"], ["Stable", "Steady", "Constant"]),
  GyanWord("Wane", "v.", "घटना / क्षीण होना", "To become smaller or weaker", "Public interest in the scheme began to wane.", ["Decline", "Dwindle", "Ebb"], ["Wax", "Increase", "Grow"]),
  GyanWord("Wary", "adj.", "सतर्क", "Cautious about possible danger", "Be wary of fake news.", ["Cautious", "Watchful", "Vigilant"], ["Careless", "Reckless", "Unwary"]),
  GyanWord("Zealous", "adj.", "उत्साही / उत्कट", "Showing great energy for a cause", "He is a zealous worker for the bank union.", ["Ardent", "Fervent", "Enthusiastic"], ["Apathetic", "Indifferent", "Lukewarm"]),
  GyanWord("Zenith", "n.", "शिखर / चरम बिंदु", "The highest point", "The company reached its zenith in 2019.", ["Peak", "Summit", "Pinnacle"], ["Nadir", "Base", "Bottom"]),
];

const List<GyanFact> kGyanFacts = [
  // ------------------------------- General Science -------------------------------
  GyanFact("Science", "The SI unit of luminous intensity is the candela, luminous flux is measured in lumen, and illuminance in lux.", "ज्योति-तीव्रता का SI मात्रक कैंडेला, ज्योति-फ्लक्स का ल्यूमेन और प्रदीप्ति का लक्स है।"),
  GyanFact("Science", "The Chandrasekhar limit, about 1.4 times the mass of the Sun, is the maximum mass of a stable white dwarf star.", "चंद्रशेखर सीमा (सूर्य के द्रव्यमान का लगभग 1.4 गुना) एक स्थिर श्वेत वामन तारे का अधिकतम द्रव्यमान है।"),
  GyanFact("Science", "C. V. Raman discovered the Raman Effect, the scattering of light with a change in wavelength, on 28 February 1928; the day is celebrated as National Science Day.", "सी. वी. रमन ने 28 फरवरी 1928 को रमन प्रभाव खोजा (प्रकाश के प्रकीर्णन में तरंगदैर्ध्य बदलना); यह दिन राष्ट्रीय विज्ञान दिवस है।"),
  GyanFact("Science", "Bose–Einstein condensate is called the fifth state of matter, and the particle class ‘boson’ is named after the Indian physicist S. N. Bose.", "बोस–आइंस्टीन संघनित को पदार्थ की पाँचवीं अवस्था कहते हैं, और ‘बोसॉन’ कण का नाम भारतीय भौतिकशास्त्री एस. एन. बोस पर रखा गया है।"),
  GyanFact("Science", "Food cooks faster in a pressure cooker because higher pressure raises the boiling point of water above 100 °C.", "प्रेशर कुकर में खाना जल्दी पकता है क्योंकि अधिक दाब पर पानी का क्वथनांक 100 °C से ऊपर चला जाता है।"),
  GyanFact("Science", "The sky looks blue because of Rayleigh scattering, which is proportional to 1/λ⁴; red light scatters the least, so it is used for danger signals.", "आकाश नीला रेले प्रकीर्णन (1/λ⁴ के समानुपाती) के कारण दिखता है; लाल प्रकाश सबसे कम बिखरता है, इसलिए खतरे के संकेत में उपयोग होता है।"),
  GyanFact("Science", "Optical fibres work on total internal reflection, which happens only when light travels from a denser to a rarer medium at an angle greater than the critical angle.", "ऑप्टिकल फाइबर पूर्ण आंतरिक परावर्तन पर काम करते हैं; यह तभी होता है जब प्रकाश सघन से विरल माध्यम में क्रांतिक कोण से बड़े कोण पर जाए।"),
  GyanFact("Science", "Sound travels fastest in solids, slower in liquids and slowest in gases, and it cannot travel through a vacuum.", "ध्वनि ठोस में सबसे तेज़, द्रव में उससे धीमी और गैस में सबसे धीमी चलती है, और निर्वात में नहीं चल सकती।"),
  GyanFact("Science", "Mercury and bromine are the only two elements that are liquid at room temperature.", "पारा और ब्रोमीन ही ऐसे दो तत्व हैं जो कमरे के तापमान पर द्रव अवस्था में होते हैं।"),
  GyanFact("Science", "Aqua regia, a 3:1 mixture of concentrated hydrochloric acid and nitric acid, can dissolve gold and platinum.", "ऐक्वा रेजिया (सांद्र हाइड्रोक्लोरिक और नाइट्रिक अम्ल का 3:1 मिश्रण) सोना और प्लैटिनम को घोल सकता है।"),
  GyanFact("Science", "Dry ice is solid carbon dioxide; it sublimes at −78.5 °C instead of melting.", "शुष्क बर्फ ठोस कार्बन डाइऑक्साइड है; यह पिघलने के बजाय −78.5 °C पर सीधे गैस बन जाती (ऊर्ध्वपातित होती) है।"),
  GyanFact("Science", "In the Haber process ammonia is made from nitrogen and hydrogen using an iron catalyst; in the Contact process sulphuric acid is made using vanadium pentoxide.", "हैबर विधि में लोहे के उत्प्रेरक से नाइट्रोजन और हाइड्रोजन द्वारा अमोनिया बनती है; संपर्क विधि में वैनेडियम पेंटाऑक्साइड से सल्फ्यूरिक अम्ल बनता है।"),
  GyanFact("Science", "Bleaching powder is calcium oxychloride (CaOCl₂), and plaster of Paris is calcium sulphate hemihydrate (CaSO₄·½H₂O).", "विरंजक चूर्ण कैल्सियम ऑक्सीक्लोराइड (CaOCl₂) और प्लास्टर ऑफ पेरिस कैल्सियम सल्फेट अर्धहाइड्रेट (CaSO₄·½H₂O) है।"),
  GyanFact("Science", "Bakelite was the first fully synthetic plastic, and it is a thermosetting plastic that cannot be softened again by heating.", "बेकेलाइट पहला पूर्णतः संश्लेषित प्लास्टिक था; यह तापदृढ़ (थर्मोसेटिंग) प्लास्टिक है जो गर्म करने पर दोबारा नरम नहीं होता।"),
  GyanFact("Science", "The pH of human blood is about 7.4, while gastric juice, which contains hydrochloric acid, has a pH of about 1.5 to 3.5.", "मानव रक्त का pH लगभग 7.4 होता है, जबकि हाइड्रोक्लोरिक अम्ल वाले आमाशय रस का pH लगभग 1.5 से 3.5 होता है।"),
  GyanFact("Science", "Insulin is secreted by the beta cells of the islets of Langerhans in the pancreas, and its deficiency causes diabetes mellitus.", "इंसुलिन अग्न्याशय के लैंगरहैंस द्वीप की बीटा कोशिकाओं से स्रावित होती है; इसकी कमी से मधुमेह होता है।"),
  GyanFact("Science", "Haemoglobin contains iron, chlorophyll contains magnesium, and vitamin B12 (cobalamin) contains cobalt.", "हीमोग्लोबिन में लोहा, क्लोरोफिल में मैग्नीशियम और विटामिन B12 (कोबालामिन) में कोबाल्ट होता है।"),
  GyanFact("Science", "Scurvy is caused by vitamin C deficiency, rickets by vitamin D, beriberi by vitamin B1 and pellagra by vitamin B3.", "विटामिन C की कमी से स्कर्वी, D की कमी से रिकेट्स, B1 की कमी से बेरीबेरी और B3 की कमी से पेलाग्रा होता है।"),
  GyanFact("Science", "The sinoatrial (SA) node, called the natural pacemaker of the heart, initiates each heartbeat.", "साइनोएट्रियल (SA) नोड को हृदय का प्राकृतिक पेसमेकर कहते हैं; यह हर धड़कन शुरू करता है।"),
  GyanFact("Science", "Gregor Mendel, the Father of Genetics, worked on pea plants, and his laws of inheritance were rediscovered in 1900.", "आनुवंशिकी के जनक ग्रेगर मेंडल ने मटर के पौधों पर काम किया; उनके नियम 1900 में पुनः खोजे गए।"),
  GyanFact("Science", "In photosynthesis the light reaction occurs in the thylakoids, and the dark reaction (Calvin cycle) in the stroma of the chloroplast.", "प्रकाश संश्लेषण में प्रकाश अभिक्रिया थायलाकॉइड में और अप्रकाश अभिक्रिया (कैल्विन चक्र) हरितलवक के स्ट्रोमा में होती है।"),
  GyanFact("Science", "Glycolysis takes place in the cytoplasm, while the Krebs cycle takes place in the matrix of the mitochondria.", "ग्लाइकोलिसिस कोशिका द्रव्य में और क्रेब्स चक्र माइटोकॉन्ड्रिया के मैट्रिक्स में होता है।"),
  GyanFact("Science", "Malaria is caused by the protozoan Plasmodium and spread by the female Anopheles mosquito, while dengue is spread by the Aedes mosquito.", "मलेरिया प्रोटोज़ोआ प्लाज़्मोडियम से होता है और मादा एनोफिलीज़ मच्छर फैलाती है; डेंगू एडीज़ मच्छर फैलाता है।"),
  GyanFact("Science", "The oral polio vaccine was developed by Albert Sabin, and the injectable polio vaccine by Jonas Salk.", "मुँह से दी जाने वाली पोलियो वैक्सीन अल्बर्ट सेबिन ने और इंजेक्शन वाली जोनास साल्क ने बनाई।"),
  GyanFact("Science", "Red blood cells of mammals have no nucleus, are made in the bone marrow, and live for about 120 days.", "स्तनधारियों की लाल रक्त कोशिकाओं में केंद्रक नहीं होता, ये अस्थि मज्जा में बनती हैं और लगभग 120 दिन जीवित रहती हैं।"),
  GyanFact("Science", "ISRO’s Mars Orbiter Mission was launched on 5 November 2013 and entered Mars orbit on 24 September 2014, making India the first country to succeed on its first attempt.", "इसरो का मंगलयान 5 नवंबर 2013 को छोड़ा गया और 24 सितंबर 2014 को मंगल की कक्षा में पहुँचा; पहले ही प्रयास में सफल होने वाला भारत पहला देश बना।"),
  GyanFact("Science", "Aditya-L1, India’s first solar observatory mission, was launched on 2 September 2023 and placed in a halo orbit around the Sun–Earth Lagrange point L1.", "आदित्य-L1, भारत का पहला सौर वेधशाला मिशन, 2 सितंबर 2023 को छोड़ा गया और सूर्य-पृथ्वी के लैग्रेंज बिंदु L1 के चारों ओर हेलो कक्षा में स्थापित हुआ।"),
  GyanFact("Science", "Thumba in Kerala, from where India’s first sounding rocket was launched in 1963, and Sriharikota in Andhra Pradesh, home of the Satish Dhawan Space Centre, are the main rocket launch sites of India.", "केरल का थुंबा (जहाँ से 1963 में पहला भारतीय साउंडिंग रॉकेट छोड़ा गया) और आंध्र प्रदेश का श्रीहरिकोटा (सतीश धवन अंतरिक्ष केंद्र) भारत के मुख्य रॉकेट प्रक्षेपण स्थल हैं।"),

  // --------------------------- General Studies: Polity ---------------------------
  GyanFact("Polity", "In Kesavananda Bharati v. State of Kerala (1973), a 13-judge bench ruled by 7:6 that Parliament can amend the Constitution under Article 368 but cannot alter its ‘basic structure’.", "केशवानंद भारती बनाम केरल राज्य (1973) में 13 न्यायाधीशों की पीठ ने 7:6 से कहा कि संसद अनुच्छेद 368 के तहत संविधान संशोधित कर सकती है पर इसकी ‘मूल संरचना’ नहीं बदल सकती।"),
  GyanFact("Polity", "The 42nd Amendment (1976) added the words ‘Socialist’, ‘Secular’ and ‘Integrity’ to the Preamble and inserted Fundamental Duties as Part IV-A (Article 51A).", "42वें संशोधन (1976) ने प्रस्तावना में ‘समाजवादी’, ‘पंथनिरपेक्ष’ और ‘अखंडता’ शब्द जोड़े और मूल कर्तव्य (भाग IV-A, अनुच्छेद 51A) जोड़े।"),
  GyanFact("Polity", "Fundamental Duties were added on the recommendation of the Swaran Singh Committee, and the 86th Amendment (2002) added the 11th duty: to provide education to a child aged 6 to 14 years.", "मूल कर्तव्य स्वर्ण सिंह समिति की सिफारिश पर जोड़े गए; 86वें संशोधन (2002) ने 11वाँ कर्तव्य (6 से 14 वर्ष के बच्चे को शिक्षा दिलाना) जोड़ा।"),
  GyanFact("Polity", "Dr B. R. Ambedkar called Article 32, the right to move the Supreme Court for Fundamental Rights, the ‘heart and soul’ of the Constitution.", "डॉ. बी. आर. अंबेडकर ने मौलिक अधिकारों के लिए सर्वोच्च न्यायालय जाने के अधिकार, अनुच्छेद 32, को संविधान की ‘आत्मा और हृदय’ कहा।"),
  GyanFact("Polity", "Article 226 lets High Courts issue writs for Fundamental Rights ‘and for any other purpose’, so its scope is wider than that of Article 32.", "अनुच्छेद 226 उच्च न्यायालयों को मौलिक अधिकारों ‘और किसी अन्य उद्देश्य’ के लिए रिट जारी करने देता है, इसलिए इसका दायरा अनुच्छेद 32 से व्यापक है।"),
  GyanFact("Polity", "The five writs are Habeas Corpus, Mandamus, Prohibition, Certiorari and Quo Warranto.", "पाँच रिट हैं: बंदी प्रत्यक्षीकरण, परमादेश, प्रतिषेध, उत्प्रेषण और अधिकार-पृच्छा।"),
  GyanFact("Polity", "The 44th Amendment (1978) removed the Right to Property from the Fundamental Rights and made it a legal right under Article 300A.", "44वें संशोधन (1978) ने संपत्ति के अधिकार को मौलिक अधिकारों से हटाकर अनुच्छेद 300A के तहत कानूनी अधिकार बना दिया।"),
  GyanFact("Polity", "The Anti-Defection Law is the Tenth Schedule, added by the 52nd Amendment (1985); the 91st Amendment (2003) capped the Council of Ministers at 15 percent of the House.", "दल-बदल विरोधी कानून दसवीं अनुसूची है (52वाँ संशोधन, 1985); 91वें संशोधन (2003) ने मंत्रिपरिषद को सदन की सदस्य संख्या के 15 प्रतिशत तक सीमित किया।"),
  GyanFact("Polity", "The 73rd Amendment (1992) gave constitutional status to Panchayati Raj (Part IX, Eleventh Schedule) and the 74th Amendment to urban local bodies (Part IX-A, Twelfth Schedule).", "73वें संशोधन (1992) ने पंचायती राज (भाग IX, ग्यारहवीं अनुसूची) और 74वें संशोधन ने नगरीय निकायों (भाग IX-A, बारहवीं अनुसूची) को संवैधानिक दर्जा दिया।"),
  GyanFact("Polity", "Panchayati Raj was first launched at Nagaur in Rajasthan on 2 October 1959, following the Balwant Rai Mehta Committee report.", "बलवंत राय मेहता समिति की रिपोर्ट के बाद पंचायती राज सबसे पहले 2 अक्टूबर 1959 को राजस्थान के नागौर में शुरू हुआ।"),
  GyanFact("Polity", "The 101st Amendment (2016) introduced GST, and the GST Council is constituted under Article 279A.", "101वें संशोधन (2016) ने GST लागू किया; GST परिषद अनुच्छेद 279A के तहत गठित होती है।"),
  GyanFact("Polity", "A Money Bill (Article 110) can be introduced only in the Lok Sabha, and the Rajya Sabha can only recommend changes within 14 days.", "धन विधेयक (अनुच्छेद 110) केवल लोकसभा में पेश हो सकता है और राज्यसभा 14 दिन के भीतर केवल सिफारिशें दे सकती है।"),
  GyanFact("Polity", "Joint sittings of Parliament under Article 108 have been held three times: 1961 (Dowry Prohibition Bill), 1978 (Banking Service Commission Repeal Bill) and 2002 (POTA).", "अनुच्छेद 108 के तहत संसद की संयुक्त बैठक तीन बार हुई: 1961 (दहेज निषेध विधेयक), 1978 (बैंकिंग सेवा आयोग निरसन विधेयक) और 2002 (पोटा)।"),
  GyanFact("Polity", "The Comptroller and Auditor General (Article 148) is appointed by the President and can be removed only in the same manner as a Supreme Court judge.", "नियंत्रक एवं महालेखा परीक्षक (अनुच्छेद 148) की नियुक्ति राष्ट्रपति करते हैं और उसे सर्वोच्च न्यायालय के न्यायाधीश की तरह ही हटाया जा सकता है।"),
  GyanFact("Polity", "The Election Commission is established under Article 324, and the Finance Commission under Article 280 is constituted every five years.", "निर्वाचन आयोग अनुच्छेद 324 के तहत स्थापित है और वित्त आयोग (अनुच्छेद 280) हर पाँच वर्ष में गठित होता है।"),
  GyanFact("Polity", "Under Article 72 the President can pardon death sentences and court-martial sentences; the Governor’s pardoning power under Article 161 does not cover them.", "अनुच्छेद 72 के तहत राष्ट्रपति मृत्युदंड और कोर्ट-मार्शल की सजा माफ कर सकते हैं; अनुच्छेद 161 के तहत राज्यपाल की क्षमादान शक्ति इनमें लागू नहीं होती।"),
  GyanFact("Polity", "The Constituent Assembly took 2 years, 11 months and 18 days to frame the Constitution, which was adopted on 26 November 1949 and came into force on 26 January 1950.", "संविधान सभा को संविधान बनाने में 2 वर्ष, 11 माह, 18 दिन लगे; इसे 26 नवंबर 1949 को अपनाया गया और 26 जनवरी 1950 को लागू किया गया।"),
  GyanFact("Polity", "The President is elected by an electoral college under Article 54 through proportional representation by single transferable vote; nominated members of Parliament do not vote.", "राष्ट्रपति का चुनाव अनुच्छेद 54 के तहत निर्वाचक मंडल द्वारा एकल संक्रमणीय मत द्वारा आनुपातिक प्रतिनिधित्व से होता है; मनोनीत सांसद मतदान नहीं करते।"),
  GyanFact("Polity", "Article 356 deals with President’s Rule in a state, and the S. R. Bommai case (1994) laid down strict judicial review of its use.", "अनुच्छेद 356 राज्य में राष्ट्रपति शासन से संबंधित है, और एस. आर. बोम्मई मामले (1994) ने इसके प्रयोग की सख्त न्यायिक समीक्षा तय की।"),
  GyanFact("Polity", "The Right to Information Act was passed in 2005, and the Lokpal and Lokayuktas Act in 2013.", "सूचना का अधिकार अधिनियम 2005 में और लोकपाल एवं लोकायुक्त अधिनियम 2013 में पारित हुआ।"),

  // ---------------------------- General Studies: History ----------------------------
  GyanFact("History", "Dholavira in Gujarat, a UNESCO World Heritage Site since 2021, is known for the sophisticated water-conservation system of the Harappan civilisation.", "गुजरात का धोलावीरा, जो 2021 से यूनेस्को विश्व धरोहर है, हड़प्पा सभ्यता की उन्नत जल-संरक्षण प्रणाली के लिए प्रसिद्ध है।"),
  GyanFact("History", "Lothal in Gujarat had a Harappan dockyard, and Rakhigarhi in Haryana is the largest Harappan site in India.", "गुजरात के लोथल में हड़प्पाई गोदी (डॉकयार्ड) थी और हरियाणा का राखीगढ़ी भारत का सबसे बड़ा हड़प्पाई स्थल है।"),
  GyanFact("History", "The Rigveda, the oldest Veda, has 1,028 hymns arranged in 10 mandalas.", "ऋग्वेद, सबसे पुराना वेद, में 10 मंडलों में 1,028 सूक्त हैं।"),
  GyanFact("History", "Ashoka’s war on Kalinga took place around 261 BCE, and James Prinsep deciphered the Brahmi script of his edicts in 1837.", "अशोक का कलिंग युद्ध लगभग 261 ईसा पूर्व हुआ; उसके अभिलेखों की ब्राह्मी लिपि को जेम्स प्रिंसेप ने 1837 में पढ़ा।"),
  GyanFact("History", "Kautilya wrote the Arthashastra in the Mauryan period, and the Greek envoy Megasthenes wrote Indica.", "मौर्य काल में कौटिल्य ने अर्थशास्त्र लिखा और यूनानी राजदूत मेगस्थनीज़ ने इंडिका लिखी।"),
  GyanFact("History", "Samudragupta, called the ‘Napoleon of India’ by V. A. Smith, is praised in the Allahabad Pillar inscription composed by Harishena.", "वी. ए. स्मिथ ने समुद्रगुप्त को ‘भारत का नेपोलियन’ कहा; हरिषेण द्वारा रचित प्रयाग प्रशस्ति (इलाहाबाद स्तंभ लेख) में उनकी प्रशंसा है।"),
  GyanFact("History", "The Chola king Rajaraja I built the Brihadeeswarar Temple at Thanjavur, completed around 1010 CE.", "चोल राजा राजराज प्रथम ने तंजावुर का बृहदेश्वर मंदिर बनवाया, जो लगभग 1010 ई. में पूरा हुआ।"),
  GyanFact("History", "The three Battles of Panipat were fought in 1526 (Babur and Ibrahim Lodi), 1556 (Akbar’s forces and Hemu) and 1761 (the Marathas and Ahmad Shah Abdali).", "पानीपत की तीन लड़ाइयाँ 1526 (बाबर–इब्राहीम लोदी), 1556 (अकबर की सेना–हेमू) और 1761 (मराठे–अहमद शाह अब्दाली) में हुईं।"),
  GyanFact("History", "Sher Shah Suri defeated Humayun at Chausa (1539) and Kannauj (1540) and introduced the silver rupiya.", "शेरशाह सूरी ने हुमायूँ को चौसा (1539) और कन्नौज (1540) में हराया और चाँदी का रुपया चलाया।"),
  GyanFact("History", "Akbar’s land-revenue system Zabt was developed by Raja Todar Mal, and his Mansabdari system ranked officers by zat and sawar.", "अकबर की भू-राजस्व व्यवस्था ज़ब्त का विकास राजा टोडरमल ने किया; मनसबदारी में अधिकारियों का दर्जा ज़ात और सवार से तय होता था।"),
  GyanFact("History", "Alauddin Khalji started the systems of dagh (branding of horses) and chehra (descriptive rolls of soldiers) and controlled market prices.", "अलाउद्दीन खिलजी ने दाग (घोड़ों को दागना) और चेहरा (सैनिकों का हुलिया) प्रणाली शुरू की और बाज़ार मूल्य नियंत्रित किए।"),
  GyanFact("History", "Muhammad bin Tughlaq shifted his capital from Delhi to Daulatabad in 1327 and issued token currency.", "मुहम्मद बिन तुगलक ने 1327 में राजधानी दिल्ली से दौलताबाद बदली और सांकेतिक मुद्रा चलाई।"),
  GyanFact("History", "The Vijayanagara Empire was founded in 1336 by Harihara and Bukka, and its power broke at the Battle of Talikota in 1565.", "विजयनगर साम्राज्य की स्थापना 1336 में हरिहर और बुक्का ने की; तालीकोटा के युद्ध (1565) में इसकी शक्ति टूट गई।"),
  GyanFact("History", "Lord Cornwallis introduced the Permanent Settlement in 1793, Thomas Munro the Ryotwari system in Madras, and Holt Mackenzie the Mahalwari system in 1822.", "लॉर्ड कॉर्नवालिस ने 1793 में स्थायी बंदोबस्त, थॉमस मुनरो ने मद्रास में रैयतवाड़ी और होल्ट मैकेंज़ी ने 1822 में महालवाड़ी व्यवस्था लागू की।"),
  GyanFact("History", "Lord Dalhousie’s Doctrine of Lapse was used to annex Satara (1848), Jhansi (1853) and Nagpur (1854).", "लॉर्ड डलहौज़ी की हड़प नीति से सतारा (1848), झाँसी (1853) और नागपुर (1854) का विलय हुआ।"),
  GyanFact("History", "The Indian National Congress was founded in 1885 by A. O. Hume, and W. C. Bonnerjee presided over its first session in Bombay.", "भारतीय राष्ट्रीय कांग्रेस की स्थापना 1885 में ए. ओ. ह्यूम ने की; बंबई में पहले अधिवेशन की अध्यक्षता डब्ल्यू. सी. बनर्जी ने की।"),
  GyanFact("History", "The Partition of Bengal by Lord Curzon took effect on 16 October 1905 and was annulled in 1911.", "लॉर्ड कर्ज़न द्वारा बंगाल विभाजन 16 अक्टूबर 1905 को लागू हुआ और 1911 में रद्द कर दिया गया।"),
  GyanFact("History", "Gandhi’s first satyagraha in India was at Champaran (1917), followed by Kheda and the Ahmedabad mill strike in 1918.", "भारत में गांधीजी का पहला सत्याग्रह चंपारण (1917) में हुआ, फिर 1918 में खेड़ा और अहमदाबाद मिल हड़ताल।"),
  GyanFact("History", "The Chauri Chaura incident of 5 February 1922 made Gandhi withdraw the Non-Cooperation Movement.", "5 फरवरी 1922 की चौरी-चौरा घटना के बाद गांधीजी ने असहयोग आंदोलन वापस ले लिया।"),
  GyanFact("History", "The Poona Pact (1932) was signed between Gandhi and Dr B. R. Ambedkar after the Communal Award.", "सांप्रदायिक पंचाट के बाद गांधीजी और डॉ. अंबेडकर के बीच पूना समझौता (1932) हुआ।"),
  GyanFact("History", "The Cabinet Mission of 1946 had three members: Pethick-Lawrence, Stafford Cripps and A. V. Alexander.", "1946 के कैबिनेट मिशन में तीन सदस्य थे: पेथिक-लॉरेंस, स्टैफर्ड क्रिप्स और ए. वी. अलेक्जेंडर।"),

  // --------------------------- General Studies: Geography ---------------------------
  GyanFact("Geography", "The Tropic of Cancer (23.5°N) passes through eight Indian states: Gujarat, Rajasthan, Madhya Pradesh, Chhattisgarh, Jharkhand, West Bengal, Tripura and Mizoram.", "कर्क रेखा (23.5°उ.) भारत के आठ राज्यों से गुजरती है: गुजरात, राजस्थान, मध्य प्रदेश, छत्तीसगढ़, झारखंड, पश्चिम बंगाल, त्रिपुरा और मिज़ोरम।"),
  GyanFact("Geography", "India’s Standard Meridian is 82°30′E, which passes near Mirzapur in Uttar Pradesh, and IST is 5 hours 30 minutes ahead of GMT.", "भारत की मानक याम्योत्तर 82°30′ पूर्व है, जो उत्तर प्रदेश के मिर्ज़ापुर के पास से गुजरती है, और IST ग्रीनविच समय से 5 घंटे 30 मिनट आगे है।"),
  GyanFact("Geography", "Kanchenjunga (8,586 m) is the highest peak in India, and Anamudi (2,695 m) in Kerala is the highest peak of peninsular India.", "कंचनजंगा (8,586 मी.) भारत की सबसे ऊँची चोटी है, और केरल की अनामुडी (2,695 मी.) प्रायद्वीपीय भारत की सबसे ऊँची चोटी है।"),
  GyanFact("Geography", "The Narmada and Tapi flow west into the Arabian Sea through rift valleys and form estuaries instead of deltas.", "नर्मदा और ताप्ती भ्रंश घाटियों से होकर पश्चिम में अरब सागर में गिरती हैं और डेल्टा के बजाय ज्वारनदमुख बनाती हैं।"),
  GyanFact("Geography", "Chilika in Odisha is the largest coastal lagoon in India, and Wular in Jammu and Kashmir is the largest freshwater lake.", "ओडिशा की चिल्का भारत की सबसे बड़ी तटीय लैगून झील है और जम्मू-कश्मीर की वुलर सबसे बड़ी मीठे पानी की झील है।"),
  GyanFact("Geography", "The Ganga is formed at Devprayag in Uttarakhand by the meeting of the Alaknanda and the Bhagirathi.", "गंगा का निर्माण उत्तराखंड के देवप्रयाग में अलकनंदा और भागीरथी के संगम से होता है।"),
  GyanFact("Geography", "The Brahmaputra is called Tsangpo in Tibet and Jamuna in Bangladesh.", "ब्रह्मपुत्र को तिब्बत में सांगपो और बांग्लादेश में जमुना कहते हैं।"),
  GyanFact("Geography", "Black soil (regur) forms from basaltic lava and suits cotton; it is rich in lime, iron and magnesium but poor in nitrogen, phosphorus and organic matter.", "काली मिट्टी (रेगुर) बेसाल्ट लावा से बनती है और कपास के लिए उपयुक्त है; इसमें चूना, लोहा और मैग्नीशियम अधिक, पर नाइट्रोजन, फॉस्फोरस और जैविक पदार्थ कम होते हैं।"),
  GyanFact("Geography", "The Hirakud Dam on the Mahanadi in Odisha is among the longest earthen dams in the world.", "ओडिशा में महानदी पर बना हीराकुंड बाँध दुनिया के सबसे लंबे मिट्टी के बाँधों में से एक है।"),
  GyanFact("Geography", "The Palk Strait separates India and Sri Lanka, and the Ten Degree Channel separates the Andaman and Nicobar Islands.", "पाक जलडमरूमध्य भारत और श्रीलंका को अलग करता है, और दस डिग्री चैनल अंडमान और निकोबार द्वीप समूह को अलग करता है।"),
  GyanFact("Geography", "Mawsynram in Meghalaya’s Khasi Hills is recorded as one of the wettest places on Earth.", "मेघालय की खासी पहाड़ियों में स्थित मॉसिनराम पृथ्वी के सबसे अधिक वर्षा वाले स्थानों में गिना जाता है।"),
  GyanFact("Geography", "The Aravalli range is among the oldest fold mountains in the world, while the Himalayas are among the youngest.", "अरावली दुनिया की सबसे पुरानी वलित पर्वतमालाओं में से एक है, जबकि हिमालय सबसे नई में से एक है।"),

  // ---------------------------- General Studies: Economy ----------------------------
  GyanFact("Economy", "The Reserve Bank of India was established on 1 April 1935 under the RBI Act 1934 and was nationalised on 1 January 1949.", "भारतीय रिज़र्व बैंक की स्थापना RBI अधिनियम 1934 के तहत 1 अप्रैल 1935 को हुई और इसका राष्ट्रीयकरण 1 जनवरी 1949 को हुआ।"),
  GyanFact("Economy", "The repo rate is the rate at which the RBI lends short-term money to banks, and the reverse repo rate is the rate at which it borrows from banks.", "रेपो दर वह दर है जिस पर RBI बैंकों को अल्पकालिक ऋण देता है, और रिवर्स रेपो दर वह दर है जिस पर वह बैंकों से उधार लेता है।"),
  GyanFact("Economy", "The Fiscal Responsibility and Budget Management (FRBM) Act was enacted in 2003 to bring fiscal discipline.", "राजकोषीय अनुशासन लाने के लिए राजकोषीय उत्तरदायित्व और बजट प्रबंधन (FRBM) अधिनियम 2003 में बना।"),
  GyanFact("Economy", "NABARD was established on 12 July 1982 on the recommendation of the Shivaraman Committee.", "नाबार्ड की स्थापना शिवरामन समिति की सिफारिश पर 12 जुलाई 1982 को हुई।"),
  GyanFact("Economy", "NITI Aayog replaced the Planning Commission on 1 January 2015.", "नीति आयोग ने 1 जनवरी 2015 को योजना आयोग का स्थान लिया।"),
  GyanFact("Economy", "The First Five-Year Plan (1951–56) was based on the Harrod–Domar model, and the Second Plan (1956–61) on the Mahalanobis model.", "पहली पंचवर्षीय योजना (1951–56) हैरोड–डोमर मॉडल पर और दूसरी योजना (1956–61) महालनोबिस मॉडल पर आधारित थी।"),
  GyanFact("Economy", "India nationalised 14 major banks in 1969 and 6 more in 1980.", "भारत ने 1969 में 14 प्रमुख बैंकों का और 1980 में 6 और बैंकों का राष्ट्रीयकरण किया।"),
  GyanFact("Economy", "Minimum Support Prices are announced by the Government of India on the recommendation of the Commission for Agricultural Costs and Prices (CACP).", "न्यूनतम समर्थन मूल्य भारत सरकार कृषि लागत एवं मूल्य आयोग (CACP) की सिफारिश पर घोषित करती है।"),

  // ----------------------------------- Static GK -----------------------------------
  GyanFact("StaticGK", "The Jnanpith Award was first given in 1965 to the Malayalam poet G. Sankara Kurup.", "ज्ञानपीठ पुरस्कार पहली बार 1965 में मलयालम कवि जी. शंकर कुरुप को दिया गया।"),
  GyanFact("StaticGK", "The Dadasaheb Phalke Award was first given in 1969 to the actress Devika Rani.", "दादासाहेब फाल्के पुरस्कार पहली बार 1969 में अभिनेत्री देविका रानी को दिया गया।"),
  GyanFact("StaticGK", "Kalidasa wrote Abhijnanashakuntalam, Bharavi wrote Kiratarjuniya, and Banabhatta wrote Harshacharita.", "कालिदास ने अभिज्ञानशाकुंतलम्, भारवि ने किरातार्जुनीयम् और बाणभट्ट ने हर्षचरित लिखा।"),
  GyanFact("StaticGK", "Kalhana’s Rajatarangini is a chronicle of the kings of Kashmir.", "कल्हण की राजतरंगिणी कश्मीर के राजाओं का इतिहास-ग्रंथ है।"),
  GyanFact("StaticGK", "The Kailasa Temple at Ellora in Maharashtra was built under the Rashtrakuta king Krishna I.", "महाराष्ट्र के एलोरा का कैलाश मंदिर राष्ट्रकूट राजा कृष्ण प्रथम के समय बना।"),
  GyanFact("StaticGK", "The Khajuraho temples were built by the Chandela rulers, and the Sun Temple at Modhera in Gujarat by the Solanki dynasty.", "खजुराहो के मंदिर चंदेल शासकों ने और गुजरात का मोढेरा सूर्य मंदिर सोलंकी वंश ने बनवाया।"),
  GyanFact("StaticGK", "Sattriya, the dance tradition of Assam, was recognised as a classical dance by the Sangeet Natak Akademi in 2000.", "असम की नृत्य परंपरा सत्त्रिया को संगीत नाटक अकादमी ने 2000 में शास्त्रीय नृत्य का दर्जा दिया।"),
  GyanFact("StaticGK", "Amartya Sen won the Nobel Prize in Economics in 1998, and Abhijit Banerjee shared it in 2019.", "अमर्त्य सेन ने 1998 में अर्थशास्त्र का नोबेल जीता, और अभिजीत बनर्जी ने 2019 में यह साझा रूप से जीता।"),

  // ------------------------- Uttar Pradesh GK (UPSSSC / UPPSC / AHC RO) -------------------------
  GyanFact("UPGK", "Uttar Pradesh has 75 districts and 18 administrative divisions.", "उत्तर प्रदेश में 75 जिले और 18 मंडल हैं।"),
  GyanFact("UPGK", "The United Provinces of Agra and Oudh was renamed Uttar Pradesh on 24 January 1950.", "संयुक्त प्रांत (आगरा और अवध) का नाम 24 जनवरी 1950 को उत्तर प्रदेश रखा गया।"),
  GyanFact("UPGK", "The Allahabad High Court was established on 17 March 1866 at Agra, shifted to Allahabad in 1869, and has a bench at Lucknow.", "इलाहाबाद उच्च न्यायालय की स्थापना 17 मार्च 1866 को आगरा में हुई, 1869 में इलाहाबाद आया, और इसकी एक पीठ लखनऊ में है।"),
  GyanFact("UPGK", "The Allahabad High Court has the largest sanctioned strength of judges (160) among the High Courts of India.", "भारत के उच्च न्यायालयों में इलाहाबाद उच्च न्यायालय में न्यायाधीशों के स्वीकृत पद (160) सबसे अधिक हैं।"),
  GyanFact("UPGK", "Lakhimpur Kheri is the largest district of Uttar Pradesh by area, and it has the Dudhwa National Park, known for the barasingha (swamp deer).", "लखीमपुर खीरी क्षेत्रफल में उत्तर प्रदेश का सबसे बड़ा जिला है, और यहाँ दुधवा राष्ट्रीय उद्यान है जो बारहसिंगा (दलदली हिरण) के लिए प्रसिद्ध है।"),
  GyanFact("UPGK", "The Chauri Chaura incident (1922) took place in Gorakhpur district, and the Kakori train action took place near Lucknow on 9 August 1925.", "चौरी-चौरा की घटना (1922) गोरखपुर जिले में हुई, और काकोरी ट्रेन एक्शन 9 अगस्त 1925 को लखनऊ के पास हुआ।"),
  GyanFact("UPGK", "The Revolt of 1857 began at Meerut on 10 May 1857.", "1857 का विद्रोह 10 मई 1857 को मेरठ से शुरू हुआ।"),
  GyanFact("UPGK", "Sarnath near Varanasi is where the Buddha gave his first sermon, and its Ashoka Lion Capital is the basis of India’s national emblem.", "वाराणसी के पास सारनाथ में बुद्ध ने पहला उपदेश दिया था, और यहाँ का अशोक सिंह-स्तंभ शीर्ष भारत के राष्ट्रीय चिह्न का आधार है।"),
  GyanFact("UPGK", "The Taj Mahal, Agra Fort and Fatehpur Sikri, all in the Agra region, are UNESCO World Heritage Sites.", "आगरा क्षेत्र के ताजमहल, आगरा किला और फतेहपुर सीकरी यूनेस्को विश्व धरोहर स्थल हैं।"),
  GyanFact("UPGK", "The Uttar Pradesh Vidhan Sabha has 403 members and the Vidhan Parishad has 100; the state sends 80 members to the Lok Sabha and 31 to the Rajya Sabha.", "उत्तर प्रदेश विधानसभा में 403 और विधान परिषद में 100 सदस्य हैं; राज्य से लोकसभा में 80 और राज्यसभा में 31 सदस्य जाते हैं।"),
  GyanFact("UPGK", "Govind Ballabh Pant was the first Chief Minister of Uttar Pradesh after 1950, and Sucheta Kripalani became India’s first woman Chief Minister in Uttar Pradesh in 1963.", "गोविंद बल्लभ पंत 1950 के बाद उत्तर प्रदेश के पहले मुख्यमंत्री थे, और सुचेता कृपलानी 1963 में उत्तर प्रदेश में भारत की पहली महिला मुख्यमंत्री बनीं।"),
  GyanFact("UPGK", "Banaras Hindu University was founded in 1916 by Madan Mohan Malaviya, and Aligarh Muslim University received university status in 1920.", "बनारस हिंदू विश्वविद्यालय की स्थापना 1916 में मदन मोहन मालवीय ने की, और अलीगढ़ मुस्लिम विश्वविद्यालय को 1920 में विश्वविद्यालय का दर्जा मिला।"),
  GyanFact("UPGK", "The Upper Ganga Canal, built under Proby Cautley, was opened in 1854 and irrigates the doab region of Uttar Pradesh.", "प्रोबी कॉटले के नेतृत्व में बनी ऊपरी गंगा नहर 1854 में खुली और उत्तर प्रदेश के दोआब क्षेत्र की सिंचाई करती है।"),
  GyanFact("UPGK", "The Kumbh Mela is held at Prayagraj, Haridwar, Ujjain and Nashik, and the Maha Kumbh at Prayagraj comes once in 12 years.", "कुंभ मेला प्रयागराज, हरिद्वार, उज्जैन और नासिक में लगता है, और प्रयागराज का महाकुंभ 12 वर्ष में एक बार आता है।"),
];
