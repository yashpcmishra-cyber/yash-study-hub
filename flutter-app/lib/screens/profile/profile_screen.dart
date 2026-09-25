import 'package:flutter/material.dart';
import '../../app_globals.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../home_screen.dart';

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
      setState(() => _error = 'Please fill in all fields. / Saari details bharo.');
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated! / Profile update ho gayi!')));
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

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isSetup,
      child: Scaffold(
        backgroundColor: const Color(0xFF050B24),
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isSetup,
          title: Text(widget.isSetup ? 'Complete Your Profile' : 'My Profile'),
          actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout)],
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
                        const Text(
                          'One last step — tell us a bit about yourself.\nEk aakhri step — apne baare mein thoda batao.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 12.5), textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      TextField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _dec('Full Name *', Icons.person_outline)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _state,
                        dropdownColor: const Color(0xFF081136),
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('State *', Icons.map_outlined),
                        items: kIndianStatesAndUTs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _state = v),
                      ),
                      const SizedBox(height: 14),
                      TextField(controller: _district, style: const TextStyle(color: Colors.white), decoration: _dec('District *', Icons.location_city_outlined)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        dropdownColor: const Color(0xFF081136),
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Gender *', Icons.wc_outlined),
                        items: kGenders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _qualification,
                        dropdownColor: const Color(0xFF081136),
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Qualification *', Icons.school_outlined),
                        items: kQualifications.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                        onChanged: (v) => setState(() => _qualification = v),
                      ),
                      if (_qualification == 'Other') ...[
                        const SizedBox(height: 14),
                        TextField(controller: _qualOther, style: const TextStyle(color: Colors.white), decoration: _dec('Please specify', Icons.edit_outlined)),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5), textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(widget.isSetup ? 'Save & Continue' : 'Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
