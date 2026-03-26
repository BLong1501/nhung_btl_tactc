import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../config/firebase_config.dart';

class SensorListenerService {
  static final SensorListenerService _instance =
      SensorListenerService._internal();

  factory SensorListenerService() {
    return _instance;
  }

  SensorListenerService._internal();

  String? _lastStatus;
  StreamSubscription<DatabaseEvent>? _subscription;
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(VoidCallback callback) {
    _listeners.remove(callback);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Lắng nghe thay đổi trạng thái HC-SR04 từ Firebase
  void startListening({
    required String deviceId,
    required Function(String status, String message) onStatusChanged,
  }) {
    _subscription?.cancel();

    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: FIREBASE_DATABASE_URL,
    );
    final ref = database
        .ref()
        .child('devices')
        .child(deviceId)
        .child('status')
        .child('food_level');

    _subscription = ref.onValue.listen(
      (DatabaseEvent event) {
        if (event.snapshot.exists) {
          final status = event.snapshot.value as String?;

          if (status != null && status != _lastStatus) {
            _lastStatus = status;

            final message = _getMessageForStatus(status);
            onStatusChanged(status, message);

            // Save notification to Firebase
            _saveNotificationToFirebase(status);

            // Notify UI listeners for badge update
            _notifyListeners();
          }
        }
      },
      onError: (error) {
        print('Sensor listener error: $error');
      },
    );
  }

  String _getMessageForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'empty':
        return 'Hộp thức ăn đã hết! Vui lòng thêm thức ăn.';
      case 'low':
        return 'Lượng thức ăn thấp, chuẩn bị thêm thức ăn.';
      case 'medium':
        return 'Lượng thức ăn trung bình.';
      case 'full':
        return 'Hộp thức ăn đầy.';
      default:
        return 'Trạng thái thức ăn thay đổi: $status';
    }
  }

  Future<void> _saveNotificationToFirebase(String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: FIREBASE_DATABASE_URL,
      );
      final notificationRef = database
          .ref()
          .child('users')
          .child(user.uid)
          .child('notifications');

      final now = DateTime.now();
      final vietnamTime = now.add(const Duration(hours: 7));

      final notification = {
        'id': 'notification_${vietnamTime.millisecondsSinceEpoch}',
        'status': status,
        'message': _getMessageForStatus(status),
        'timestamp': vietnamTime.toIso8601String(),
        'read': false,
        'createdAt': ServerValue.timestamp,
      };

      await notificationRef
          .child(notification['id']! as String)
          .set(notification);
    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stop();
    _listeners.clear();
  }
}
