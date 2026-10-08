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

  /// How far the card shrinks while pressed (1.0 = no shrink). The default
  /// keeps the original subtle 0.97 used everywhere else in the app.
  final double pressScale;

  /// Extra lightening (0.0 to 1.0) of the card colour while pressed, so the
  /// "sink" is easier to see on the dark background. 0 = off (the default).
  final double pressBrighten;

  /// Optional coloured glow. When set, the card gets a soft glow around it, a
  /// thin lit edge, a top-to-bottom shading and a glossy highlight on its top
  /// half - so it looks like a raised 3D block. Null (default) = old look.
  final Color? glowColor;

  const DepthCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.pressScale = 0.97,
    this.pressBrighten = 0.0,
    this.glowColor,
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
    final glow = widget.glowColor;
    final baseColor = widget.color ?? const Color(0xCC081136);
    final cardColor = (_pressed && widget.pressBrighten > 0)
        ? (Color.lerp(baseColor, Colors.white, widget.pressBrighten) ?? baseColor)
        : baseColor;
    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressScale : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: widget.borderRadius,
              // Lighter at the top, darker at the bottom = rounded 3D body.
              gradient: glow == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(cardColor, Colors.white, 0.10) ?? cardColor,
                        cardColor,
                        Color.lerp(cardColor, Colors.black, 0.35) ?? cardColor,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
              // Thin lit edge in the glow colour.
              border: glow == null ? null : Border.all(color: glow.withOpacity(_pressed ? 0.55 : 0.32), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_pressed ? 0.18 : 0.38),
                  blurRadius: _pressed ? 4 : 12,
                  offset: Offset(0, _pressed ? 1 : 5),
                ),
                // Soft coloured glow around the block (calms down when pressed).
                if (glow != null)
                  BoxShadow(
                    color: glow.withOpacity(_pressed ? 0.12 : 0.26),
                    blurRadius: _pressed ? 8 : 16,
                    spreadRadius: _pressed ? 0 : 0.5,
                    offset: const Offset(0, 2),
                  ),
                // A faint highlight on top gives the surface a subtle raised
                // look even when it isn't being pressed.
                if (!_pressed) BoxShadow(color: Colors.white.withOpacity(0.03), blurRadius: 0, offset: const Offset(0, 1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: glow == null
                  ? Material(color: Colors.transparent, child: widget.child)
                  : Stack(
                      fit: StackFit.expand, // content pehle ki tarah poore tile me centre rahe
                      children: [
                        Material(color: Colors.transparent, child: widget.child),
                        // Glossy shine over the top half; taps pass straight through.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 34,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.white.withOpacity(0.13), Colors.white.withOpacity(0.0)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
