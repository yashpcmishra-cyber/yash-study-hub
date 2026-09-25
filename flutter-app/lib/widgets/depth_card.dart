import 'package:flutter/material.dart';

/// A drop-in replacement for [Card] that adds a tactile "3D" feel: a soft
/// drop-shadow gives it depth at rest, and on tap it sinks slightly (shadow
/// softens, card scales down a touch) then springs back up on release —
/// like a real button being pressed.
///
/// Usage is the same shape as Card + InkWell:
///   DepthCard(
///     onTap: () => ...,
///     child: ListTile(...),
///   )
class DepthCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry margin;

  const DepthCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  State<DepthCard> createState() => _DepthCardState();
}

class _DepthCardState extends State<DepthCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return; // nothing tappable, no press feedback
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? const Color(0xFF081136);
    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: widget.borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_pressed ? 0.18 : 0.38),
                  blurRadius: _pressed ? 4 : 12,
                  offset: Offset(0, _pressed ? 1 : 5),
                ),
                // A faint highlight on top gives the surface a subtle raised
                // look even when it isn't being pressed.
                if (!_pressed) BoxShadow(color: Colors.white.withOpacity(0.03), blurRadius: 0, offset: const Offset(0, 1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: Material(color: Colors.transparent, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
