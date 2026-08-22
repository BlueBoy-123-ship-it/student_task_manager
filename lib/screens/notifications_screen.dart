import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  final FirestoreService _service = FirestoreService();

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Just now';
    final date = value.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load notifications.\n${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = [...(snapshot.data?.docs ?? const [])];
          notifications.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['createdAt'];
            final bDate = bData['createdAt'];
            final aTime = aDate is Timestamp ? aDate.toDate() : DateTime(1970);
            final bTime = bDate is Timestamp ? bDate.toDate() : DateTime(1970);
            return bTime.compareTo(aTime);
          });

          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final document = notifications[index];
              final data = document.data() as Map<String, dynamic>;
              final read = data['read'] == true;
              final type = data['type']?.toString() ?? '';
              final icon = type == 'assignment_submitted'
                  ? Icons.upload_file_outlined
                  : Icons.assignment_outlined;

              return Card(
                color: read ? null : colors.primary.withValues(alpha: .08),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.primary.withValues(alpha: .12),
                    child: Icon(icon, color: colors.primary),
                  ),
                  title: Text(
                    data['title']?.toString() ?? 'Notification',
                    style: TextStyle(
                      fontWeight: read ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${data['body']?.toString() ?? ''}\n${_date(data['createdAt'])}',
                  ),
                  isThreeLine: true,
                  onTap: read
                      ? null
                      : () => _service.markNotificationRead(document.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
