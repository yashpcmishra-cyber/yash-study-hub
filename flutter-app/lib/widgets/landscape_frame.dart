import 'package:flutter/material.dart';

/// Video player jaisi screens ye counter badhati hain jab tak wo khuli hain;
/// counter 0 se zyada ho to 4:3 frame band rehta hai (video poori screen le).
final ValueNotifier<int> landscapeFrameBypass = ValueNotifier<int>(0);

/// Landscape me poori app ko 4:3 frame me, beech me dikhata hai (dono taraf
/// kaali patti). Portrait me kuch nahi badalta. Widget ka tree hamesha ek
/// jaisa rehta hai, isliye rotate karne par screens ka state nahi khota.
class LandscapeFrame extends StatelessWidget {
  final Widget child;
  const LandscapeFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    return ValueListenableBuilder<int>(
      valueListenable: landscapeFrameBypass,
      builder: (context, bypass, _) {
        final frameW = screen.height * 4 / 3;
        final framed = screen.width > screen.height && bypass == 0 && screen.width > frameW + 1;
        final w = framed ? frameW : screen.width;
        final data = framed
            ? mq.copyWith(
                size: Size(w, screen.height),
                padding: mq.padding.copyWith(left: 0, right: 0),
                viewPadding: mq.viewPadding.copyWith(left: 0, right: 0),
              )
            : mq;
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: SizedBox(
              width: w,
              height: screen.height,
              child: MediaQuery(data: data, child: child),
            ),
          ),
        );
      },
    );
  }
}
