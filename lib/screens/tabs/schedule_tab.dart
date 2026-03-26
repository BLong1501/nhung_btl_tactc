import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../config/firebase_config.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final DatabaseReference _deviceRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: FIREBASE_DATABASE_URL,
  ).ref('devices/$DEVICE_ID');

  Map schedules = {};
  late StreamSubscription _schedulesSubscription;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() {
    _schedulesSubscription = _deviceRef
        .child('schedule/schedules')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.value != null && mounted) {
              setState(() {
                schedules = event.snapshot.value as Map? ?? {};
              });
            }
          },
          onError: (error) {
            print('Schedules listener error: $error');
          },
        );
  }

  @override
  void dispose() {
    _schedulesSubscription.cancel();
    super.dispose();
  }

  Future<void> _addNewSchedule() async {
    String scheduleId = 'schedule_${DateTime.now().millisecondsSinceEpoch}';
    String time = '07:00';
    String amount = 'medium';
    List<int> defaultDays = [2, 3, 4, 5, 6];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ScheduleDialog(
        title: 'Thêm lịch cho ăn',
        initialTime: time,
        initialAmount: amount,
        initialDays: defaultDays,
        onSave: (newTime, newAmount, newDays) async {
          final amountToDuration = {'small': 2, 'medium': 3, 'large': 4};
          int duration = amountToDuration[newAmount] ?? 3;

          await _deviceRef.child('schedule/schedules/$scheduleId').set({
            'time': newTime,
            'amount': newAmount,
            'duration_sec': duration,
            'days': newDays,
            'enabled': true,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Đã thêm lịch thành công!')),
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _editSchedule(String scheduleId, var schedule) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ScheduleDialog(
        title: 'Chỉnh sửa lịch',
        initialTime: schedule['time'] ?? '07:00',
        initialAmount: schedule['amount'] ?? 'medium',
        initialDays: List<int>.from(schedule['days'] ?? [2, 3, 4, 5, 6]),
        onSave: (newTime, newAmount, newDays) async {
          final amountToDuration = {'small': 2, 'medium': 3, 'large': 4};
          int duration = amountToDuration[newAmount] ?? 3;

          await _deviceRef.child('schedule/schedules/$scheduleId').update({
            'time': newTime,
            'amount': newAmount,
            'duration_sec': duration,
            'days': newDays,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Đã cập nhật lịch!')),
            );
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    await _deviceRef.child('schedule/schedules/$scheduleId').remove();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✓ Đã xóa lịch!')));
    }
  }

  Future<void> _toggleSchedule(String scheduleId, bool currentState) async {
    await _deviceRef
        .child('schedule/schedules/$scheduleId/enabled')
        .set(!currentState);
  }

  List<MapEntry> _getSortedSchedules() {
    List<MapEntry> entries = schedules.entries.toList();
    entries.sort((a, b) {
      String timeA = a.value['time'] ?? '00:00';
      String timeB = b.value['time'] ?? '00:00';
      return timeA.compareTo(timeB);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    var sortedSchedules = _getSortedSchedules();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange[400]!, Colors.orange[800]!],
          ),
        ),
        child: sortedSchedules.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.schedule,
                        size: 80,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Chưa có lịch cho ăn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tạo lịch tự động để thú cưng được ăn đúng giờ',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _addNewSchedule,
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo lịch'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedSchedules.length,
                itemBuilder: (context, index) {
                  String scheduleId = sortedSchedules[index].key;
                  var schedule = sortedSchedules[index].value;
                  bool enabled = schedule['enabled'] ?? true;
                  List<int> days = schedule['days'] != null
                      ? List<int>.from(schedule['days'])
                      : [2, 3, 4, 5, 6];

                  final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
                  String dayString = days
                      .map((d) => dayNames[d % 7])
                      .join(', ');

                  final amountLabels = {
                    'small': 'Ít',
                    'medium': 'Vừa',
                    'large': 'Nhiều',
                  };
                  String amount = schedule['amount'] ?? 'medium';
                  String amountLabel = amountLabels[amount] ?? 'Vừa';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    color: Colors.white.withOpacity(0.95),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? Colors.orange[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.schedule,
                              color: enabled ? Colors.orange[700] : Colors.grey,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          // Time - prominent
                          Text(
                            schedule['time'] ?? '07:00',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Amount + emoji
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.orange[200]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              amount == 'small'
                                  ? 'Ít 🍗'
                                  : amount == 'medium'
                                  ? 'Vừa 🍖'
                                  : 'Nhiều 🍗🍖',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dayString,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Sửa'),
                              ],
                            ),
                            onTap: () {
                              Future.delayed(Duration.zero, () {
                                _editSchedule(scheduleId, schedule);
                              });
                            },
                          ),
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Xóa'),
                              ],
                            ),
                            onTap: () {
                              Future.delayed(Duration.zero, () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Xóa lịch?'),
                                    content: const Text(
                                      'Bạn có chắc chắn muốn xóa lịch này?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Hủy'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          _deleteSchedule(scheduleId);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text(
                                          'Xóa',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Toggle switch
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: enabled,
                                onChanged: (value) {
                                  _toggleSchedule(scheduleId, enabled);
                                },
                                activeColor: Colors.orange,
                                inactiveThumbColor: Colors.grey,
                              ),
                            ),
                            const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewSchedule,
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange[700],
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

// ============================================================================
// SCHEDULE DIALOG - Add/Edit Schedule (Bottom Sheet with Wheel Pickers)
// ============================================================================

class _ScheduleDialog extends StatefulWidget {
  final String title;
  final String initialTime;
  final String initialAmount;
  final List<int> initialDays;
  final Function(String time, String amount, List<int> days) onSave;

  const _ScheduleDialog({
    required this.title,
    required this.initialTime,
    required this.initialAmount,
    required this.initialDays,
    required this.onSave,
  });

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late String _selectedTime;
  late String _selectedAmount;
  late List<int> _selectedDays;

  final List<String> _dayNames = [
    'Chủ nhật',
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
    _selectedAmount = widget.initialAmount;
    _selectedDays = List.from(widget.initialDays);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // Time Picker (Wheel - iPhone style)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⏰ Chọn giờ cho ăn',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: Stack(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Hours
                                Expanded(
                                  child: ListWheelScrollView.useDelegate(
                                    itemExtent: 45,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (index) {
                                      String hour = (index % 24)
                                          .toString()
                                          .padLeft(2, '0');
                                      String minute = _selectedTime.split(
                                        ':',
                                      )[1];
                                      setState(
                                        () => _selectedTime = '$hour:$minute',
                                      );
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                          builder: (context, index) {
                                            String hourValue = (index % 24)
                                                .toString()
                                                .padLeft(2, '0');
                                            bool isSelected =
                                                hourValue ==
                                                _selectedTime.split(':')[0];
                                            return Center(
                                              child: Text(
                                                hourValue,
                                                style: TextStyle(
                                                  fontSize: isSelected
                                                      ? 32
                                                      : 24,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? Colors.orange[800]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            );
                                          },
                                          childCount: 24,
                                        ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    ':',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                // Minutes
                                Expanded(
                                  child: ListWheelScrollView.useDelegate(
                                    itemExtent: 45,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (index) {
                                      String hour = _selectedTime.split(':')[0];
                                      String minute = (index % 60)
                                          .toString()
                                          .padLeft(2, '0');
                                      setState(
                                        () => _selectedTime = '$hour:$minute',
                                      );
                                    },
                                    childDelegate:
                                        ListWheelChildBuilderDelegate(
                                          builder: (context, index) {
                                            String minuteValue = (index % 60)
                                                .toString()
                                                .padLeft(2, '0');
                                            bool isSelected =
                                                minuteValue ==
                                                _selectedTime.split(':')[1];
                                            return Center(
                                              child: Text(
                                                minuteValue,
                                                style: TextStyle(
                                                  fontSize: isSelected
                                                      ? 32
                                                      : 24,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? Colors.orange[800]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            );
                                          },
                                          childCount: 60,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            // Center highlight indicator (iPhone style)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 52,
                              bottom: 52,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange[100]?.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange[300]!,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Amount Selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🍖 Chọn lượng cho ăn',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: ['small', 'medium', 'large']
                            .map((amount) {
                              bool isSelected = _selectedAmount == amount;
                              String label = amount == 'small'
                                  ? 'Ít 🍗'
                                  : amount == 'medium'
                                  ? 'Vừa 🍖'
                                  : 'Nhiều 🍗🍖';

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedAmount = amount);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue[400]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue[400]!
                                            : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) => entry.value)
                            .toList()
                            .fold<List<Widget>>([], (prev, current) {
                              if (prev.isEmpty) {
                                return [current];
                              }
                              return [
                                ...prev,
                                const SizedBox(width: 8),
                                current,
                              ];
                            }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Days Selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📅 Chọn ngày trong tuần',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (index) {
                          bool isSelected = _selectedDays.contains(index);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedDays.remove(index);
                                } else {
                                  _selectedDays.add(index);
                                  _selectedDays.sort();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green[400]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green[400]!
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                _dayNames[index],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_selectedDays.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Vui lòng chọn ít nhất một ngày!',
                                ),
                              ),
                            );
                            return;
                          }
                          widget.onSave(
                            _selectedTime,
                            _selectedAmount,
                            _selectedDays,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Lưu',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
