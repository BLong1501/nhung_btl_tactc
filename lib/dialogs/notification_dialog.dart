import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/firebase_config.dart';

class SensorNotification {
  final String id;
  final String status; // 'empty', 'low', 'medium', 'full'
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final bool read;

  SensorNotification({
    required this.id,
    required this.status,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.read = false,
  });

  factory SensorNotification.fromMap(Map<dynamic, dynamic> map) {
    final statusValue = (map['status'] ?? 'unknown').toString().toLowerCase();
    final timestamp = _parseTimestamp(map['timestamp']);
    final (icon, color) = _getIconAndColor(statusValue);

    return SensorNotification(
      id: map['id'] ?? 'unknown',
      status: statusValue,
      message: map['message'] ?? 'Thông báo từ cảm biến',
      timestamp: timestamp,
      icon: icon,
      color: color,
      read: map['read'] == true,
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).add(const Duration(hours: 7));
      } catch (e) {
        return DateTime.now().add(const Duration(hours: 7));
      }
    }
    return DateTime.now().add(const Duration(hours: 7));
  }

  static (IconData, Color) _getIconAndColor(String status) {
    switch (status) {
      case 'empty':
        return (Icons.warning_amber_rounded, Colors.red);
      case 'low':
        return (Icons.info_outline, Colors.orange);
      case 'medium':
        return (Icons.circle_outlined, Colors.blue);
      case 'full':
        return (Icons.check_circle_outline, Colors.green);
      default:
        return (Icons.help_outline, Colors.grey);
    }
  }
}

class NotificationDialog extends StatefulWidget {
  const NotificationDialog({Key? key}) : super(key: key);

  /// Static method to get unread notification count (for badge)
  static Future<int> getUnreadCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final ref = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('notifications');

      final snapshot = await ref.get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;

        int unreadCount = 0;
        data.forEach((key, value) {
          if (value is Map && value['read'] != true) {
            unreadCount++;
          }
        });
        return unreadCount;
      }
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  late Future<List<SensorNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchNotifications();
    // Mark all as read when dialog opens
    _markAllAsRead();
  }

  Future<List<SensorNotification>> _fetchNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: FIREBASE_DATABASE_URL,
      );
      final ref = database
          .ref()
          .child('users')
          .child(user.uid)
          .child('notifications');

      final snapshot = await ref.get();

      if (snapshot.exists) {
        final List<SensorNotification> notifications = [];
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value is Map) {
            try {
              final notif = SensorNotification.fromMap(
                Map<dynamic, dynamic>.from(value),
              );
              notifications.add(notif);
            } catch (e) {
              print('Error parsing notification: $e');
            }
          }
        });

        // Sort by timestamp descending (newest first)
        notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return notifications;
      }
      return [];
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: FIREBASE_DATABASE_URL,
      );
      final ref = database
          .ref()
          .child('users')
          .child(user.uid)
          .child('notifications');

      final snapshot = await ref.get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value is Map && value['read'] != true) {
            ref.child(key).update({'read': true});
          }
        });
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(time.year, time.month, time.day);

    if (notificationDate == today) {
      return 'Hôm nay';
    } else if (notificationDate == yesterday) {
      return 'Hôm qua';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thông báo'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<SensorNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return const Center(
                child: Text(
                  'Chưa có thông báo nào',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: notif.color.withAlpha(100),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    color: notif.read
                        ? notif.color.withAlpha(10)
                        : notif.color.withAlpha(25),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: notif.color.withAlpha(50),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(notif.icon, color: notif.color, size: 20),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notif.read
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: notif.color,
                            ),
                          ),
                        ),
                        if (!notif.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: notif.color,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${_formatDate(notif.timestamp)} lúc ${_formatTime(notif.timestamp)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
