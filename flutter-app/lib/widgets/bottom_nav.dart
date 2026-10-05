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
  // inside it (not only exactly on the icon or text). The press animation
  // lives inside _NavItem, so only the tapped tab redraws (not the bar or
  // the Home screen).
  Widget _item(IconData icon, String label, int index) {
    return Expanded(
      child: _NavItem(
        icon: icon,
        label: label,
        active: currentIndex == index,
        onTap: () => onTap(index),
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

/// Landscape me neeche ka menu ki jagah left side ki patti. Isse list /
/// content ko ~60dp zyada height milti hai. Tabs wahi hain, bas khade.
class YshSideNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const YshSideNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  Widget _item(IconData icon, String label, int index) {
    return Expanded(
      child: _NavItem(
        icon: icon,
        label: label,
        active: currentIndex == index,
        onTap: () => onTap(index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      right: false,
      child: Container(
        width: 68,
        decoration: const BoxDecoration(
          color: Color(0xFF0A1440),
          border: Border(right: BorderSide(color: Color(0xFF16276A))),
        ),
        child: Column(
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

/// One tab of the bottom bar. On tap it sinks a little (shrinks and dips
/// down ~110 ms) and springs back on release, like a real button. The
/// press state is local to this tiny widget. onTap still fires exactly once
/// per tap, and the whole tab area stays tappable (HitTestBehavior.opaque).
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? const Color(0xFFFFFF29) : Colors.grey;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _pressed ? const Offset(0, 0.05) : Offset.zero,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
