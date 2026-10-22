import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../app_globals.dart';
import '../../models/models.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/open_link.dart';
import '../auth/login_screen.dart';
import '../home_screen.dart';
import '../../app_colors.dart';

// Fixed, stable list — doesn't need a backend/admin update ever.
const List<String> kIndianStatesAndUTs = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana',
  'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
  'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
  'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi (NCT)', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
];
const List<String> kGenders = ['Male', 'Female', 'Other'];
const List<String> kQualifications = ['10th Pass', '12th Pass', 'Graduate', 'Post Graduate', 'Other'];

/// Two jobs, one screen:
///  - isSetup=true  -> mandatory Step 2 right after Sign Up / first Login
///    (splash_screen.dart routes here when profileComplete is false). Back
///    is disabled; only "Save" or "Logout" can leave this screen.
///  - isSetup=false -> the Profile tab in the bottom nav, used to view/edit
///    the same details any time (see bottom_nav.dart / home_screen.dart).
class ProfileScreen extends StatefulWidget {
  final bool isSetup;
  const ProfileScreen({super.key, this.isSetup = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _fs = FirestoreService();
  final _name = TextEditingController();
  final _district = TextEditingController();
  final _qualOther = TextEditingController();
  String? _state;
  String? _gender;
  String? _qualification;
  String _email = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _district.dispose();
    _qualOther.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    _email = user?.email ?? '';
    try {
      if (user != null) {
        final profile = await _fs.getStudentProfile(user.uid);
        if (profile != null) {
          _name.text = profile.name;
          _district.text = profile.district;
          _state = profile.state.isNotEmpty ? profile.state : null;
          _gender = profile.gender.isNotEmpty ? profile.gender : null;
          if (profile.qualification.isNotEmpty) {
            if (kQualifications.contains(profile.qualification)) {
              _qualification = profile.qualification;
            } else {
              _qualification = 'Other';
              _qualOther.text = profile.qualification;
            }
          }
        }
      }
    } catch (_) {
      // Offline — form just starts blank/last-known; Save will retry.
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final district = _district.text.trim();
    final qualMissingOther = _qualification == 'Other' && _qualOther.text.trim().isEmpty;
    if (name.isEmpty || _state == null || district.isEmpty || _gender == null || _qualification == null || qualMissingOther) {
      setState(() => _error = 'Please fill in all fields. / सारी जानकारी भरें।');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = _auth.currentUser!.uid;
      final qual = _qualification == 'Other' ? _qualOther.text.trim() : _qualification!;
      await _fs.saveStudentProfile(StudentModel(
        uid: uid,
        name: name,
        email: _email,
        state: _state!,
        district: district,
        gender: _gender!,
        qualification: qual,
        profileComplete: true,
      ));
      await syncLocalStudentIdentity(_email, name);
      if (!mounted) return;
      if (widget.isSetup) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated! / प्रोफ़ाइल अपडेट हो गई!')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save. Please check your internet connection and try again.";
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  // "Delete Account": warning + password check in ONE dialog. Only when the
  // dialog returns true (data and login are already deleted) do we leave.
  Future<void> _deleteAccount() async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (done != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your account and data have been deleted. / आपका अकाउंट और डेटा डिलीट हो गया है।')),
    );
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppC.muted),
        prefixIcon: Icon(icon, color: AppC.muted),
      );

  Widget _contactSection() {
    final links = <_SocialLink>[
      _SocialLink(FontAwesomeIcons.telegram, 'Telegram', const Color(0xFF229ED9), 'https://t.me/YashStudyHub'),
      _SocialLink(FontAwesomeIcons.whatsapp, 'WhatsApp', const Color(0xFF25D366), 'https://whatsapp.com/channel/0029VbCnzSvKmCPLxoMBuk33'),
      _SocialLink(FontAwesomeIcons.instagram, 'Instagram', const Color(0xFFD6249F), kInstagramUrl),
      _SocialLink(FontAwesomeIcons.facebookF, 'Facebook', const Color(0xFF1877F2), kFacebookUrl),
      _SocialLink(FontAwesomeIcons.envelope, 'Mail', const Color(0xFFFF9800), 'mailto:officialteamysh@gmail.com'),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: AppC.divider2, height: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Contact and Join Us',
                style: TextStyle(color: AppC.softYellowText, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Divider(color: AppC.divider2, height: 1)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: links.map((l) {
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openExternalLink(context, l.url),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: l.color,
                        child: FaIcon(l.icon, color: Colors.white, size: 17),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l.label, style: TextStyle(color: AppC.text, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isSetup,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isSetup,
          title: Text(widget.isSetup ? 'Complete Your Profile' : 'My Profile'),
          actions: [
            // Icon with its name written under it, right next to Logout.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _deleteAccount,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_forever_outlined, color: const Color(0xFFFF5252), size: 24),
                    Text('Delete Account', style: TextStyle(color: const Color(0xFFFF5252), fontSize: 9.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.isSetup) ...[
                        Text(
                          'One last step — tell us a bit about yourself.\nएक आखिरी स्टेप — अपने बारे में थोड़ा बताइए।',
                          style: TextStyle(color: AppC.text70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(_email, style: TextStyle(color: AppC.muted, fontSize: 12.5), textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      TextField(controller: _name, style: TextStyle(color: AppC.text), decoration: _dec('Full Name *', Icons.person_outline)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _state,
                        dropdownColor: AppC.card,
                        style: TextStyle(color: AppC.text),
                        decoration: _dec('State *', Icons.map_outlined),
                        items: kIndianStatesAndUTs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _state = v),
                      ),
                      const SizedBox(height: 14),
                      TextField(controller: _district, style: TextStyle(color: AppC.text), decoration: _dec('District *', Icons.location_city_outlined)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        dropdownColor: AppC.card,
                        style: TextStyle(color: AppC.text),
                        decoration: _dec('Gender *', Icons.wc_outlined),
                        items: kGenders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _qualification,
                        dropdownColor: AppC.card,
                        style: TextStyle(color: AppC.text),
                        decoration: _dec('Qualification *', Icons.school_outlined),
                        items: kQualifications.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                        onChanged: (v) => setState(() => _qualification = v),
                      ),
                      if (_qualification == 'Other') ...[
                        const SizedBox(height: 14),
                        TextField(controller: _qualOther, style: TextStyle(color: AppC.text), decoration: _dec('Please specify', Icons.edit_outlined)),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_error!, style: TextStyle(color: AppC.orange, fontSize: 12.5), textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(widget.isSetup ? 'Save & Continue' : 'Save Changes'),
                      ),
                      if (!widget.isSetup) ...[
                        const SizedBox(height: 26),
                        _contactSection(),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Confirmation dialog for Delete Account. Pops `true` only after the data
/// AND the login have really been deleted; stays open (with a red message)
/// if the password is wrong or something fails.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AccountService().deleteAccount(_password.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Widget _line(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: TextStyle(color: color ?? AppC.text70, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppC.card,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppC.redText),
            SizedBox(width: 8),
            Expanded(child: Text('Delete Account?', style: TextStyle(color: AppC.text))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line('This will permanently delete your login and your data. This cannot be undone.', color: AppC.text),
              _line('यह आपका लॉगिन और डेटा हमेशा के लिए हटा देगा। वापस नहीं आ सकता।', color: AppC.text),
              const SizedBox(height: 8),
              _line('\u2022 Your profile (name, state, district, gender, qualification)'),
              _line('\u2022 Your doubts / queries and the replies'),
              _line('\u2022 Your email login'),
              const SizedBox(height: 6),
              _line(
                'Note: the admin\u2019s paid-batch access / payment record is not removed.',
                color: AppC.muted,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                style: TextStyle(color: AppC.text),
                decoration: InputDecoration(
                  labelText: 'Enter password to confirm',
                  labelStyle: TextStyle(color: AppC.muted),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppC.muted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: TextStyle(color: AppC.orange, fontSize: 12.5)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppC.text))
                : const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }
}

class _SocialLink {
  final FaIconData icon;
  final String label;
  final Color color;
  final String url;
  const _SocialLink(this.icon, this.label, this.color, this.url);
}
