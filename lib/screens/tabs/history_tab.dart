import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../config/firebase_config.dart';
import 'package:intl/intl.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final DatabaseReference _deviceRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: FIREBASE_DATABASE_URL,
  ).ref('devices/$DEVICE_ID');

  List<Map<String, dynamic>> allHistory = [];
  List<Map<String, dynamic>> displayedHistory = [];
  late StreamSubscription _historySubscription;

  DateTime? filterStartDate;
  DateTime? filterEndDate;
  int itemsPerPage = 10;
  int currentPage = 0;

  // Selection mode
  bool isSelectionMode = false;
  Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _autoDeleteOldLogs();
  }

  void _loadHistory() {
    _historySubscription = _deviceRef
        .child('history/feeding_log')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.value != null && mounted) {
              Map<String, dynamic> data = Map<String, dynamic>.from(
                event.snapshot.value as Map<dynamic, dynamic>,
              );
              List<Map<String, dynamic>> history = [];

              data.forEach((key, value) {
                history.add({
                  'id': key,
                  'timestamp': value['timestamp'] ?? 0,
                  'action': value['action'] ?? '',
                  'duration_sec': value['duration_sec'] ?? 0,
                  'amount': value['amount'] ?? 'unknown',
                  'requested_by': value['requested_by'] ?? 'unknown',
                  'success': value['success'] ?? false,
                });
              });

              // Sort by timestamp descending
              history.sort(
                (a, b) =>
                    (b['timestamp'] as int).compareTo(a['timestamp'] as int),
              );

              setState(() {
                allHistory = history;
                currentPage = 0;
                _applyFilter();
              });
            }
          },
          onError: (error) {
            print('History listener error: $error');
          },
        );
  }

  void _applyFilter() {
    List<Map<String, dynamic>> filtered = allHistory;

    if (filterStartDate != null || filterEndDate != null) {
      filtered = filtered.where((item) {
        DateTime itemDate = DateTime.fromMillisecondsSinceEpoch(
          (item['timestamp'] as int) * 1000,
        );
        itemDate = DateTime(itemDate.year, itemDate.month, itemDate.day);

        if (filterStartDate != null &&
            itemDate.isBefore(
              DateTime(
                filterStartDate!.year,
                filterStartDate!.month,
                filterStartDate!.day,
              ),
            )) {
          return false;
        }

        if (filterEndDate != null &&
            itemDate.isAfter(
              DateTime(
                filterEndDate!.year,
                filterEndDate!.month,
                filterEndDate!.day,
              ),
            )) {
          return false;
        }

        return true;
      }).toList();
    }

    setState(() {
      displayedHistory = filtered;
      currentPage = 0;
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> history,
  ) {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var item in history) {
      // Convert to milliseconds if needed, then to Vietnam time (UTC+7)
      int timestamp = item['timestamp'] as int;
      int timestampMs = timestamp < 10000000000 ? timestamp * 1000 : timestamp;
      DateTime utcTime = DateTime.fromMillisecondsSinceEpoch(
        timestampMs,
        isUtc: true,
      );
      DateTime vietnamTime = utcTime.add(const Duration(hours: 7));
      String dateKey = DateFormat('yyyy-MM-dd').format(vietnamTime);
      String displayDate = _getDisplayDate(vietnamTime);

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add({...item, 'display_date': displayDate});
    }

    return grouped;
  }

  String _getDisplayDate(DateTime date) {
    // Get Vietnam current time (UTC+7)
    DateTime nowUtc = DateTime.now().toUtc();
    DateTime now = nowUtc.add(const Duration(hours: 7));
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime targetDate = DateTime(date.year, date.month, date.day);

    final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    final dayName = dayNames[date.weekday % 7];
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    if (targetDate == today) {
      return 'Hôm nay ($dayName, $dateStr)';
    } else if (targetDate == yesterday) {
      return 'Hôm qua ($dayName, $dateStr)';
    } else {
      return '$dayName, $dateStr';
    }
  }

  String _formatDateTime(int timestamp) {
    // Convert to milliseconds if needed, then to Vietnam time (UTC+7)
    int timestampMs = timestamp < 10000000000 ? timestamp * 1000 : timestamp;
    DateTime utcTime = DateTime.fromMillisecondsSinceEpoch(
      timestampMs,
      isUtc: true,
    );
    // Add 7 hours for Vietnam timezone (UTC+7)
    DateTime vietnamTime = utcTime.add(const Duration(hours: 7));
    return DateFormat('HH:mm:ss').format(vietnamTime);
  }

  String _getAmountEmoji(String amount) {
    switch (amount) {
      case 'small':
        return 'Ít 🍗';
      case 'medium':
        return 'Vừa 🍖';
      case 'large':
        return 'Nhiều 🍗🍖';
      default:
        return amount;
    }
  }

  Future<void> _deleteHistoryEntry(String id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: const Text('Bạn có chắc chắn muốn xóa bản ghi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deviceRef.child('history/feeding_log/$id').remove();
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Đã xóa bản ghi!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openDateRangeFilter() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: filterStartDate != null && filterEndDate != null
          ? DateTimeRange(start: filterStartDate!, end: filterEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        filterStartDate = picked.start;
        filterEndDate = picked.end;
      });
      _applyFilter();
    }
  }

  void _clearFilter() {
    setState(() {
      filterStartDate = null;
      filterEndDate = null;
    });
    _applyFilter();
  }

  // Auto delete logs older than 7 days from the latest log
  Future<void> _autoDeleteOldLogs() async {
    if (allHistory.isEmpty) return;

    // Find the latest timestamp
    int latestTimestamp = allHistory
        .map((item) => item['timestamp'] as int)
        .reduce((a, b) => a > b ? a : b);

    // Calculate 7 days ago in seconds
    int sevenDaysAgo = latestTimestamp - (7 * 24 * 60 * 60);

    // Find logs to delete
    List<String> logsToDelete = [];
    allHistory.forEach((item) {
      if ((item['timestamp'] as int) < sevenDaysAgo) {
        logsToDelete.add(item['id'] as String);
      }
    });

    // Delete them
    for (String id in logsToDelete) {
      await _deviceRef.child('history/feeding_log/$id').remove();
    }

    if (logsToDelete.isNotEmpty) {
      print(
        '[HistoryTab] 🗑️ Auto-deleted ${logsToDelete.length} logs older than 7 days',
      );
    }
  }

  Future<void> _deleteSelectedLogs() async {
    if (selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa các bản ghi đã chọn?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa ${selectedIds.length} bản ghi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              for (String id in selectedIds) {
                await _deviceRef.child('history/feeding_log/$id').remove();
              }
              if (mounted) {
                Navigator.pop(context);
                setState(() {
                  selectedIds.clear();
                  isSelectionMode = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Đã xóa ${selectedIds.length} bản ghi!'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  @override
  void dispose() {
    _historySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pagination
    int totalPages = (displayedHistory.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    int startIdx = currentPage * itemsPerPage;
    int endIdx = (startIdx + itemsPerPage).clamp(0, displayedHistory.length);
    List<Map<String, dynamic>> pageItems = displayedHistory.sublist(
      startIdx,
      endIdx,
    );

    Map<String, List<Map<String, dynamic>>> groupedByDate = _groupByDate(
      pageItems,
    );
    List<String> sortedDates = groupedByDate.keys.toList();
    sortedDates.sort((a, b) => b.compareTo(a)); // Sort descending

    return Scaffold(
      appBar: AppBar(
        title: isSelectionMode
            ? Text('${selectedIds.length} mục được chọn')
            : const Text('📊 Lịch sử cho ăn'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color.fromARGB(255, 78, 226, 206),
        actions: [
          if (isSelectionMode) ...[
            // Delete selected button
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Xóa những mục được chọn',
              onPressed: selectedIds.isEmpty ? null : _deleteSelectedLogs,
            ),
            // Cancel selection button
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Hủy chọn',
              onPressed: () {
                setState(() {
                  isSelectionMode = false;
                  selectedIds.clear();
                });
              },
            ),
          ] else ...[
            // Toggle selection mode button
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Chọn nhiều',
              onPressed: () {
                setState(() {
                  isSelectionMode = true;
                });
              },
            ),
            // Filter button
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: _openDateRangeFilter,
              tooltip: 'Lọc theo ngày',
            ),
            // Clear filter button
            if (filterStartDate != null || filterEndDate != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearFilter,
                tooltip: 'Xóa bộ lọc',
              ),
          ],
        ],
      ),
      body: displayedHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.history,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chưa có lịch sử cho ăn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filterStartDate != null || filterEndDate != null
                        ? 'Không tìm thấy dữ liệu trong khoảng thời gian chọn'
                        : 'Hãy cho thú cưng ăn để bắt đầu!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, dateIndex) {
                String dateKey = sortedDates[dateIndex];
                List<Map<String, dynamic>> entriesForDate =
                    groupedByDate[dateKey]!;
                String displayDate = entriesForDate[0]['display_date'];

                // Check if all entries for this date are selected
                Set<String> idsForThisDate = entriesForDate
                    .map((e) => e['id'] as String)
                    .toSet();
                bool allSelectedForThisDate = idsForThisDate.every(
                  (id) => selectedIds.contains(id),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: allSelectedForThisDate
                          ? Colors.blue[400]!
                          : Colors.amber[400]!,
                      width: allSelectedForThisDate ? 2 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      // Date Header with checkbox
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: allSelectedForThisDate
                              ? Colors.blue[100]
                              : Colors.yellow[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(11),
                            topRight: Radius.circular(11),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: allSelectedForThisDate
                                  ? Colors.blue[300]!
                                  : Colors.amber[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                displayDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: allSelectedForThisDate
                                      ? Colors.blue[800]
                                      : Colors.orange[800],
                                ),
                              ),
                            ),
                            Text(
                              '${entriesForDate.length} lần',
                              style: TextStyle(
                                fontSize: 12,
                                color: allSelectedForThisDate
                                    ? Colors.blue[700]
                                    : Colors.amber[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isSelectionMode)
                              Checkbox(
                                value: allSelectedForThisDate,
                                onChanged: (_) {
                                  setState(() {
                                    if (allSelectedForThisDate) {
                                      // Deselect all for this date
                                      for (String id in idsForThisDate) {
                                        selectedIds.remove(id);
                                      }
                                    } else {
                                      // Select all for this date
                                      selectedIds.addAll(idsForThisDate);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),

                      // Entries for this date
                      ...entriesForDate.asMap().entries.map((entryData) {
                        int entryIndex = entryData.key;
                        var entry = entryData.value;
                        bool success = entry['success'] == true;
                        bool isSelected = selectedIds.contains(entry['id']);
                        String timestamp = _formatDateTime(entry['timestamp']);
                        String amount = _getAmountEmoji(entry['amount']);
                        bool isLastEntry =
                            entryIndex == entriesForDate.length - 1;

                        return Container(
                          margin: const EdgeInsets.all(0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue[50]
                                : (success ? Colors.green[50] : Colors.red[50]),
                            border: Border(
                              bottom: isLastEntry
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: Colors.grey[200]!,
                                      width: 0.5,
                                    ),
                            ),
                            borderRadius: isLastEntry
                                ? const BorderRadius.only(
                                    bottomLeft: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  )
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: success
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                success
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: success ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  timestamp,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: Colors.orange[200]!,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    amount,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: isSelectionMode
                                ? () {
                                    _toggleSelection(entry['id']);
                                  }
                                : null,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: displayedHistory.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey[300]!,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page info
                  Text(
                    'Trang ${currentPage + 1} / $totalPages (${displayedHistory.length} mục)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  // Pagination buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: currentPage > 0
                            ? () {
                                setState(() => currentPage--);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Trước'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: currentPage < totalPages - 1
                            ? () {
                                setState(() => currentPage++);
                              }
                            : null,
                        label: const Text('Sau'),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
