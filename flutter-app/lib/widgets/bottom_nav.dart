import 'package:flutter/material.dart';

class YshBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const YshBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // Each tab fills an equal share of the bar and reacts to a tap anywhere
  // inside it (not only exactly on the icon or text).
  Widget _item(IconData icon, String label, int index) {
    final active = currentIndex == index;
    final color = active ? const Color(0xFFFFFF29) : Colors.grey;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea (top: false) automatically adds extra bottom padding on
    // gesture-navigation phones (where there's no dedicated nav-bar space)
    // and adds nothing extra on button/3-key navigation phones — so the
    // icons/text never sit under the system gesture strip or nav buttons,
    // on ANY phone brand/size, without hardcoding a device-specific number.
    //
    // The center "+" (Quick Menu / hidden Admin Login) was removed — the
    // Home screen's own "Quick Access" grid already covers the same
    // shortcuts, and Admin Login now lives behind a long-press on the
    // app logo at the top-left of the Home screen (see home_screen.dart).
    // Profile replaces it at the right end of the bar.
    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0xFF0A1440),
          border: Border(top: BorderSide(color: Color(0xFF16276A))),
        ),
        child: Row(
          children: [
            _item(Icons.home, 'Home', 0),
            _item(Icons.newspaper, 'News', 1),
            _item(Icons.picture_as_pdf, 'PDFs', 2),
            _item(Icons.account_balance, 'C.Affairs', 3),
            _item(Icons.person, 'Profile', 4),
          ],
        ),
      ),
    );
  }
}
