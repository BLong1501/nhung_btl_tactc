import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // ========== Firebase References ==========
  late DatabaseReference _foodLevelRef;
  late DatabaseReference _historyRef;
  late DatabaseReference _commandRef;

  // ========== Stream Subscriptions ==========
  late StreamSubscription<DatabaseEvent> _foodLevelSubscription;
  late StreamSubscription<DatabaseEvent> _historySubscription;

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

    print('[HomeTab] Firebase refs initialized');
  }

  void _setupListeners() {
    // Lắng nghe thay đổi mức thức ăn
    _foodLevelSubscription = _foodLevelRef.onValue.listen(
      (DatabaseEvent event) {
        if (mounted && event.snapshot.value != null) {
          final value = event.snapshot.value;
          setState(() {
            _foodLevel = (value is int) ? value.toDouble() : (value as double);
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
            'Điều khiển cho ăn cho thú cưng của bạn',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.greyDark.withOpacity(0.7),
            ),
          ),
          SizedBox(height: AppConstants.paddingLarge),

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

                // Food Level Info Text
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Thức ăn hiện tại: ',
                        style: AppTextStyles.bodyMedium,
                      ),
                      TextSpan(
                        text: '${_foodLevel.toStringAsFixed(0)}%',
                        style: AppTextStyles.heading2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppConstants.paddingLarge),

          // ===== Amount Selector Section =====
          Text('📊 Chọn Lượng Cho Ăn', style: AppTextStyles.heading2),
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
              Text('📝 Lịch Sử Gần Đây', style: AppTextStyles.heading2),
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
            Column(
              children: _recentHistory.take(4).map((history) {
                final timestamp = history['timestamp'] as int;
                final amount = history['amount'] as String? ?? 'medium';

                return Container(
                  margin: EdgeInsets.only(bottom: AppConstants.paddingSmall),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    border: Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Thời gian
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.greyDark,
                        ),
                      ),
                      // Lượng cho ăn
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${amountLabels[amount] ?? 'Vừa'} ${amountEmojis[amount] ?? '🍖'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
    print('[HomeTab] Disposed - all listeners cancelled');
    super.dispose();
  }
}
