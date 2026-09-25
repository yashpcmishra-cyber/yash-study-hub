# Kya badla — Tap-to-copy UPI + Telegram screenshot flow

Ye poori `flutter-app` folder tumhari original wali hai, sirf 4 files mein
change hua hai. Koi naya package add nahi hua — `flutter pub get` ki bhi
zaroorat nahi, seedha build kar sakte ho.

## Badli hui files
1. `lib/screens/batch_detail_screen.dart` — asli change yahi hai:
   - UPI "tap → app khulne ki koshish" hata diya. Ab UPI ID box par tap
     karne se **sirf clipboard mein copy** hoti hai (koi redirect attempt
     nahi) — bilingual confirmation message ke saath.
   - "How to unlock / अनलॉक कैसे करें" — 4 bilingual (English + Hindi)
     numbered steps add kiye.
   - Ek naya **"Send screenshot on Telegram"** button — ye Admin ➜ Branding
     mein jo "Telegram URL" set hai (`cfg.telegramUrl`), usi ko kholta hai.
     Koi naya admin field nahi banaya — wahi existing field reuse kiya hai.
   - **Naam field add kiya** — ab "Check Access" dabaane se pehle Naam aur
     Email dono bharna zaroori hai (pehle sirf email tha).
2. `lib/services/firestore_service.dart` — `submitAccessRequest` ab naam
   bhi save karta hai.
3. `lib/models/models.dart` — `AccessRequestModel` mein `studentName` field.
4. `lib/screens/admin/admin_panel_screen.dart` — Grants tab ki pending list
   mein ab naam bhi dikhta hai (email ke saath).

## Tumhe kya karna hai
- **Admin ➜ Branding ➜ Telegram URL** mein `https://t.me/YSHinfo` daal do
  (agar abhi kuch aur hai to update kar dena) — bas ek baar.
- Baaki sab automatic hai — koi extra setup nahi.

## Student ka naya experience
1. UPI ID par tap → copy ho jaati hai
2. Apne payment app mein paste karke pay karta hai
3. "Send screenshot on Telegram" dabata hai → seedha @YSHinfo chat khulti hai
4. Wahan screenshot bhejta hai
5. App mein wapas aake apna Naam + Email bharke "Check Access" dabata hai
   (isse tumhe Admin ➜ Grants mein request dikh jaati hai, naam ke saath)
6. Tum screenshot dekh ke Grants tab se ek-tap "Grant" karte ho, jaisa
   pehle karte the — koi change nahi isme.
