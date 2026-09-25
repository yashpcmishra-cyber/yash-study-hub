import 'package:flutter/material.dart';

/// Spinner shown while a list is loading for the first time.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Friendly "nothing here yet" message.
class EmptyView extends StatelessWidget {
  final String message;
  const EmptyView(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}

/// Shown when Firestore returns an error (no internet, missing index,
/// rules not published...). The small grey line helps the developer see
/// the real reason instead of a fake "nothing found" message.
class ErrorView extends StatelessWidget {
  final Object? error;
  const ErrorView({super.key, this.error});

  String _short(Object e) {
    final s = e.toString();
    return s.length > 220 ? '${s.substring(0, 220)}...' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white38, size: 36),
            const SizedBox(height: 10),
            const Text(
              "Couldn't load this right now.\nPlease check your internet connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                _short(error!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps a loading / empty / error message in a scrollable, so the
/// pull-down-to-refresh gesture still works on those screens too.
class PullableMessage extends StatelessWidget {
  final Widget child;
  const PullableMessage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: child)],
        );
      },
    );
  }
}
