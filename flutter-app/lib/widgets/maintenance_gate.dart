import 'package:flutter/material.dart';
import '../services/remote_flags.dart';

/// Remote Config mein maintenance_enabled = true hote hi poori app ke upar
/// ek lal patti dikhti hai. Baaki app normal chalta rehta hai (patti sirf
/// jaankari deti hai, kuch block nahi karti).
///
/// main.dart ke MaterialApp.builder mein child ko isse lapeta gaya hai.
class MaintenanceGate extends StatelessWidget {
  final Widget child;
  const MaintenanceGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFlags.changes,
      builder: (context, _, __) {
        final msg = RemoteFlags.maintenanceMessage;
        final show = RemoteFlags.maintenance && msg.isNotEmpty;
        final top = MediaQuery.paddingOf(context).top;
        // Widget ka dhaancha hamesha ek jaisa rakha hai, taaki neeche ka
        // Navigator patti aate-jaate dobara na bane (screens ki state bachi rahe).
        return Column(
          children: [
            show
                ? Material(
                    color: const Color(0xFFB3261E),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.build_circle_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: show,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
