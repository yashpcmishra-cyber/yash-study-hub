import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/models.dart';
import '../widgets/depth_card.dart';
import '../widgets/state_views.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _fs = FirestoreService();
  late final Stream<List<NotificationModel>> _stream = _fs.streamNotifications();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          final items = snap.data!;
          if (items.isEmpty) return const EmptyView('No notifications yet');
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return DepthCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Text('🔔', style: TextStyle(fontSize: 22)),
                  title: Text(n.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(n.body, style: const TextStyle(color: Colors.grey)),
                  trailing: n.sentAt != null ? Text(DateFormat('d MMM').format(n.sentAt!), style: const TextStyle(color: Colors.grey, fontSize: 10)) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
