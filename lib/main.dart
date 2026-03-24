import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PetFeederApp());
}

class PetFeederApp extends StatelessWidget {
  const PetFeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Pet Feeder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================================
// KHUNG ĐIỀU HƯỚNG CHÍNH (BOTTOM NAVIGATION BAR)
// ============================================================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Danh sách 4 màn hình tương ứng với 4 tab
  final List<Widget> _screens = [
    const HomeTab(),
    const CameraTab(),
    const ScheduleTab(),
    const HistoryTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Pet Feeder', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: _screens[_selectedIndex], // Hiển thị màn hình theo index được chọn
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Đặt lịch'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: TRANG CHỦ (Chức năng cho ăn thủ công đã làm)
// ============================================================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Thay đường link Firebase của bạn vào đây
  final DatabaseReference _deviceRef = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://nhung-btl-tactc-default-rtdb.asia-southeast1.firebasedatabase.app/')
      .ref('devices/esp32_device_01');

  double _foodLevel = 0.0;
  String _status = 'Đang tải...';
  int _feedDuration = 4;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listenToDeviceData();
  }

  void _listenToDeviceData() {
    _deviceRef.child('food_level_percent').onValue.listen((event) {
      if (event.snapshot.value != null) {
        if (mounted) {
          setState(() {
            _foodLevel = double.parse(event.snapshot.value.toString());
          });
        }
      }
    });

    _deviceRef.child('status').onValue.listen((event) {
      if (event.snapshot.value != null) {
        if (mounted) {
          setState(() {
            _status = event.snapshot.value.toString();
          });
        }
      }
    });
  }

  Future<void> sendFeedCommand() async {
    setState(() => _isLoading = true);

    try {
      await _deviceRef.child('commands/latest').set({
        'action': 'feed_now',
        'status': 'pending',
        'params': {
          'duration_sec': _feedDuration,
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lệnh cho ăn thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _status == 'online' ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _status == 'online' ? Icons.wifi : Icons.wifi_off,
                  color: _status == 'online' ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trạng thái: ${_status.toUpperCase()}',
                  style: TextStyle(
                    color: _status == 'online' ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: _foodLevel / 100,
                  strokeWidth: 15,
                  backgroundColor: Colors.grey.shade200,
                  color: _foodLevel > 20 ? Colors.orange : Colors.red,
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.pets, size: 40, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(
                    '${_foodLevel.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                  const Text('Thức ăn còn lại', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 50),
          const Text('Thời gian thả hạt (giây):', style: TextStyle(fontSize: 16)),
          Slider(
            value: _feedDuration.toDouble(),
            min: 2,
            max: 10,
            divisions: 8,
            label: _feedDuration.toString(),
            onChanged: (value) {
              setState(() {
                _feedDuration = value.toInt();
              });
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : sendFeedCommand,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.restaurant),
              label: const Text('CHO ĂN NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 2: CAMERA (Placeholder)
// ============================================================================
class CameraTab extends StatelessWidget {
  const CameraTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Màn hình hiển thị Camera IP', style: TextStyle(fontSize: 20)));
  }
}

// ============================================================================
// TAB 3: ĐẶT LỊCH (Placeholder)
// ============================================================================
class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Màn hình Hẹn giờ cho ăn', style: TextStyle(fontSize: 20)));
  }
}

// ============================================================================
// TAB 4: LỊCH SỬ (Placeholder)
// ============================================================================
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Màn hình Lịch sử cho ăn', style: TextStyle(fontSize: 20)));
  }
}