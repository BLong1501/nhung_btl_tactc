import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/firebase_config.dart';
import '../../widgets/home/food_level_circle.dart';
import '../../widgets/home/feed_amount_selector.dart';
import '../../widgets/home/feed_button.dart';

/// ============================================================================
/// HOME TAB - Main Screen for Manual Feeding Control & Real-time Monitoring
/// ============================================================================

class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;

  const HomeTab({Key? key, this.onNavigateToHistory}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  // ========== State Variables ==========
  double _foodLevel = 0;
  String _selectedAmount = 'medium';
  bool _isFeedingInProgress = false;
  bool _showSuccessCheckmark = false;
  List<Map<String, dynamic>> _recentHistory = [];
  bool _isLoadingHistory = true;
  String _previousFoodLevelStatus =
      'unknown'; // Track previous status for change detection

  // ========== Firebase References ==========
  late DatabaseReference _foodLevelRef;
  late DatabaseReference _historyRef;
  late DatabaseReference _commandRef;
  late DatabaseReference _notificationsRef;

  // ========== Stream Subscriptions ==========
  late StreamSubscription<DatabaseEvent> _foodLevelSubscription;
  late StreamSubscription<DatabaseEvent> _historySubscription;
  OverlayEntry? _notificationOverlay;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseReferences();
    _setupListeners();
  }

  void _initializeFirebaseReferences() {
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: FIREBASE_DATABASE_URL,
    );
    _foodLevelRef = database.ref(
      "${AppConstants.sensorPath}/food_level_percent",
    );
    _historyRef = database.ref(AppConstants.historyPath);
    _commandRef = database.ref(AppConstants.commandPath);

    // Initialize notifications ref
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationsRef = database.ref('users/${user.uid}/notifications');
    }

    print('[HomeTab] Firebase refs initialized');
  }

  void _setupListeners() {
    // Lắng nghe thay đổi mức thức ăn
    _foodLevelSubscription = _foodLevelRef.onValue.listen(
      (DatabaseEvent event) {
        if (mounted && event.snapshot.value != null) {
          final value = event.snapshot.value;
          final newLevel = (value is int)
              ? value.toDouble()
              : (value as double);
          final newStatus = _getFoodLevelStatus(newLevel);

          // ✅ Kiểm tra nếu status thay đổi
          if (newStatus != _previousFoodLevelStatus &&
              _previousFoodLevelStatus != 'unknown') {
            _showFoodLevelChangeToast(newStatus);
            _saveSensorNotification(newStatus);
          }

          setState(() {
            _foodLevel = newLevel;
            _previousFoodLevelStatus = newStatus;
          });
        }
      },
      onError: (error) {
        print('[HomeTab] Lỗi lắng nghe mức thức ăn: $error');
      },
    );

    // Lắng nghe thay đổi lịch sử cho ăn - XỬ LÝ TRỰC TIẾP TỪ EVENT
    _historySubscription = _historyRef.onValue.listen(
      (event) {
        print(
          '[HomeTab] 📚 Listener triggered! Event value: ${event.snapshot.value}',
        );

        if (event.snapshot.value != null && mounted) {
          Map<String, dynamic> data = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>,
          );

          print('[HomeTab] 📊 Tổng số log: ${data.length}');

          List<Map<String, dynamic>> history = [];

          data.forEach((key, value) {
            print('[HomeTab] 🔍 Processing: $key -> $value');

            if (value is Map) {
              final rawTimestamp = value['timestamp'];

              // Convert to int safely
              int timestampValue = 0;
              if (rawTimestamp is int) {
                timestampValue = rawTimestamp;
              } else if (rawTimestamp is double) {
                timestampValue = rawTimestamp.toInt();
              } else if (rawTimestamp != null) {
                timestampValue = int.tryParse(rawTimestamp.toString()) ?? 0;
              }

              print(
                '[HomeTab]   Timestamp: $timestampValue (type: ${rawTimestamp.runtimeType})',
              );

              history.add({
                'timestamp': timestampValue,
                'duration_sec': value['duration_sec'] ?? 3,
                'amount': value['amount'] ?? 'medium',
              });
            }
          });

          // Sắp xếp theo timestamp giảm dần (mới nhất trước)
          history.sort(
            (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
          );

          print('[HomeTab] ✅ History sorted: $history');

          setState(() {
            _recentHistory = history;
            _isLoadingHistory = false;
          });
        } else {
          print('[HomeTab] ⚠️ Event value is null or not mounted');
          setState(() {
            _recentHistory = [];
            _isLoadingHistory = false;
          });
        }
      },
      onError: (error) {
        print('[HomeTab] ❌ Lỗi lắng nghe lịch sử: $error');
      },
    );
  }

  Future<void> _handleFeedButtonPress() async {
    if (_isFeedingInProgress) return;

    print('[HomeTab] 🎯 Nút cho ăn được bấm! Lượng: $_selectedAmount');

    setState(() {
      _isFeedingInProgress = true;
      _showSuccessCheckmark = false;
    });

    try {
      // Lấy thời gian servo từ bản đồ lượng
      final servoDuration = amountToDuration[_selectedAmount] ?? 3;
      final now = DateTime.now();

      print('[HomeTab] 📤 Chuẩn bị lệnh: duration=$servoDuration giây');
      print('[HomeTab] Đường dẫn lệnh: ${AppConstants.commandPath}');

      // Gửi lệnh cho ăn tới Firebase
      final commandData = {
        'action': 'feed_now',
        'status': 'pending',
        'params': {'duration_sec': servoDuration},
        'amount': _selectedAmount,
        'timestamp': now.millisecondsSinceEpoch,
      };

      print('[HomeTab] 📝 Gửi lệnh: $commandData');

      await _commandRef.set(commandData);

      print('[HomeTab] ✓ Lệnh được gửi tới Firebase thành công');
      print('[HomeTab] ⏳ Đang đợi ESP32 thực thi...');

      // Hiển thị phản hồi thành công
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _showSuccessCheckmark = true;
        });
      }

      // Thêm delay để hiển thị checkmark
      await Future.delayed(Duration(milliseconds: 800));

      // Đợi ESP32 ghi xong lịch sử (thường mất 1-2 giây)
      print('[HomeTab] ⏳ Đợi ESP32 ghi lịch sử vào Firebase...');
      print('[HomeTab] 📡 Listener sẽ tự động cập nhật lịch sử...');
      await Future.delayed(Duration(milliseconds: 2000));

      // Vô hiệu hóa button trong 3 giây
      print('[HomeTab] 🔒 Vô hiệu hóa button trong 3 giây...');
      await Future.delayed(Duration(milliseconds: 1000));

      if (mounted) {
        setState(() {
          _isFeedingInProgress = false;
          _showSuccessCheckmark = false;
        });
      }

      print('[HomeTab] ✓ Sẵn sàng cho lệnh tiếp theo');
    } catch (e) {
      print('[HomeTab] ❌ LỖI gửi lệnh cho ăn: $e');
      if (mounted) {
        setState(() {
          _isFeedingInProgress = false;
          _showSuccessCheckmark = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi lệnh cho ăn: $e'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Convert food level percentage to status
  String _getFoodLevelStatus(double foodLevel) {
    if (foodLevel >= 75) return 'full'; // Đầy
    if (foodLevel >= 50) return 'medium'; // Trung bình
    if (foodLevel >= 25) return 'low'; // Ít
    if (foodLevel > 0) return 'empty'; // Sắp hết
    return 'empty'; // Sắp hết
  }

  /// Show notification at top-right corner with animation
  void _showFoodLevelChangeToast(String newStatus) {
    String message = '';
    Color bgColor = Colors.grey;

    switch (newStatus) {
      case 'full':
        message = '🟢 Thức ăn đầy - Sẵn sàng cho ăn!';
        bgColor = const Color.fromARGB(255, 148, 224, 150);
        break;
      case 'medium':
        message = '🟡 Thức ăn ở mức trung bình';
        bgColor = Colors.blue;
        break;
      case 'low':
        message = '🟠 Thức ăn ít - Vui lòng thêm thức ăn';
        bgColor = const Color.fromARGB(255, 241, 223, 57);
        break;
      case 'empty':
        message = '🔴 Thức ăn sắp hết - Cần thêm ngay!';
        bgColor = const Color.fromARGB(255, 245, 79, 68);
        break;
    }

    // Remove previous notification if exists
    _notificationOverlay?.remove();

    // Create new notification overlay
    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        right: 16,
        child: _NotificationWidget(
          message: message,
          bgColor: bgColor,
          onDismiss: () {
            _notificationOverlay?.remove();
            _notificationOverlay = null;
          },
        ),
      ),
    );

    // Insert overlay
    Overlay.of(context).insert(_notificationOverlay!);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (_notificationOverlay != null) {
        _notificationOverlay?.remove();
        _notificationOverlay = null;
      }
    });
  }

  /// Save sensor notification to Firebase
  Future<void> _saveSensorNotification(String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notificationId = '${DateTime.now().millisecondsSinceEpoch}';
      final message = _getNotificationMessage(status);
      final timestamp = DateTime.now().toIso8601String();

      await _notificationsRef.child(notificationId).set({
        'id': notificationId,
        'status': status,
        'message': message,
        'timestamp': timestamp,
        'read': false,
        'type': 'sensor_food_level',
      });

      print('[HomeTab] ✅ Thông báo đã lưu: $notificationId');
    } catch (e) {
      print('[HomeTab] ❌ Lỗi lưu thông báo: $e');
    }
  }

  /// Get notification message based on status
  String _getNotificationMessage(String status) {
    switch (status) {
      case 'full':
        return 'Thức ăn đã đầy';
      case 'medium':
        return 'Mức thức ăn ở trung bình';
      case 'low':
        return 'Mức thức ăn thấp - Cần thêm thức ăn';
      case 'empty':
        return 'Thức ăn sắp hết - Thêm ngay';
      default:
        return 'Thông báo từ cảm biến';
    }
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '--:--';

    int timestampMs = timestamp;
    if (timestamp < 10000000000) {
      timestampMs = timestamp * 1000; // Convert seconds to milliseconds
    }

    try {
      DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime feedDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

      String timeStr =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

      if (feedDay == today) {
        return 'Hôm nay $timeStr';
      } else if (feedDay == today.subtract(Duration(days: 1))) {
        return 'Hôm qua $timeStr';
      } else {
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} $timeStr';
      }
    } catch (e) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Header =====
          Text('🏠 Bảng Điều Khiển', style: AppTextStyles.heading1),
          SizedBox(height: AppConstants.paddingSmall),
          Text(
            'Lượng thức ăn còn lại',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.greyDark),
          ),

          // ===== Food Level Section =====
          Container(
            padding: EdgeInsets.all(AppConstants.paddingLarge),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.accent.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular Food Level Indicator
                FoodLevelCircle(foodLevel: _foodLevel),
                SizedBox(height: AppConstants.paddingLarge),
              ],
            ),
          ),
          SizedBox(height: AppConstants.paddingLarge),

          // ===== Amount Selector Section =====
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon/speedometer.png', width: 28, height: 28),
              const SizedBox(width: 8),
              Text('Chọn Mức Thức Ăn', style: AppTextStyles.heading2),
            ],
          ),
          SizedBox(height: AppConstants.paddingMedium),
          FeedAmountSelector(
            initialAmount: _selectedAmount,
            isEnabled: !_isFeedingInProgress,
            onAmountChanged: (amount) {
              setState(() {
                _selectedAmount = amount;
              });
            },
          ),
          SizedBox(height: AppConstants.paddingLarge),

          // ===== Feed Button =====
          FeedButton(
            selectedAmount: _selectedAmount,
            onPressed: _handleFeedButtonPress,
            isFeeding: _isFeedingInProgress,
            showSuccess: _showSuccessCheckmark,
          ),
          SizedBox(height: AppConstants.paddingLarge),

          // ===== Recent History Section =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icon/history.png', width: 28, height: 28),
                  const SizedBox(width: 8),
                  Text('Lịch Sử Gần Đây', style: AppTextStyles.heading2),
                ],
              ),
              if (_recentHistory.isNotEmpty)
                TextButton(
                  onPressed: widget.onNavigateToHistory,
                  child: Text(
                    'Xem chi tiết →',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppConstants.paddingMedium),

          // Recent History List
          if (_isLoadingHistory)
            Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(AppConstants.paddingLarge),
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            )
          else if (_recentHistory.isEmpty)
            Container(
              padding: EdgeInsets.all(AppConstants.paddingLarge),
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              ),
              child: Center(
                child: Text(
                  '🐾 Chưa có lịch sử cho ăn',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.greyDark.withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                children: _recentHistory.take(4).map((history) {
                  final timestamp = history['timestamp'] as int;
                  final amount = history['amount'] as String? ?? 'medium';

                  return Container(
                    margin: EdgeInsets.only(bottom: AppConstants.paddingSmall),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMedium,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Cột trái: Thời gian (giữa gạch đỏ bên trái)
                        Expanded(
                          child: Center(
                            child: Text(
                              _formatTime(timestamp),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.greyDark,
                              ),
                            ),
                          ),
                        ),
                        // Cột phải: Mức + Icon (sát lề trái gạch đỏ bên phải)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  amountLabels[amount] ?? 'Vừa',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.greyDark,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  amountEmojis[amount] ?? '🍖',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          SizedBox(height: AppConstants.paddingLarge),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _foodLevelSubscription.cancel();
    _historySubscription.cancel();
    _notificationOverlay?.remove();
    print('[HomeTab] Disposed - all listeners cancelled');
    super.dispose();
  }
}

// ============================================================================
// NOTIFICATION WIDGET - Top-Right Corner Notification
// ============================================================================

class _NotificationWidget extends StatefulWidget {
  final String message;
  final Color bgColor;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.bgColor,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.5, -0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
