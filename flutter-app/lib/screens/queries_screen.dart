import 'package:flutter/material.dart';
import '../widgets/state_views.dart';

/// Placeholder — the real Queries screen (doubt + admin reply) comes in Step 2.
class QueriesScreen extends StatelessWidget {
  const QueriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Queries')),
      body: const EmptyView('Queries feature jald aa raha hai.'),
    );
  }
}
