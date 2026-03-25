import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'firebase_options.dart';

// ===== CAMERA METHOD SELECTION =====
// 0 = MJPEG (video_player) - streaming via /video endpoint
// 1 = HLS (video_player) - HTTP Live Streaming via /stream/video.m3u8
// 2 = RTSP (video_player) - Real-time streaming via rtsp://
const int CAMERA_METHOD =
    0; // ← Thay đổi giá trị này để test các phương pháp khác nhau

// ===== CAMERA ENDPOINTS =====
const String CAMERA_MJPEG_URL = 'http://192.168.0.111:8080/video';
const String CAMERA_HLS_URL = 'http://192.168.0.111:8080/stream/video.m3u8';
const String CAMERA_RTSP_URL = 'rtsp://192.168.0.111:5554/h264_ulaw.sdp';

// ============================================================================
// AUTHENTICATION SERVICE
// ============================================================================
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Đăng ký với email và password
  Future<UserCredential?> register(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('Register error: ${e.message}');
      rethrow;
    }
  }

  // Đăng nhập với email và password
  Future<UserCredential?> login(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.message}');
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // Lấy user hiện tại
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream theo dõi auth state
  Stream<User?> getAuthStateStream() {
    return _auth.authStateChanges();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(
            seedColor: Colors.orange,
          ).inversePrimary,
          elevation: 2,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Đang tải
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Nếu có user → hiển thị MainNavigationScreen
          // Nếu không → hiển thị LoginScreen
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================================
// LOGIN SCREEN - ĐĂNG NHẬP
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _errorMessage = '');

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email và password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Navigation sẽ xảy ra tự động qua StreamBuilder
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Lỗi đăng nhập');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange[400]!, Colors.orange[800]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 64,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Smart Pet Feeder',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hệ thống cấp thức ăn thông minh',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      hintText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.orange,
                                ),
                              ),
                            )
                          : const Text(
                              'Đăng nhập',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Chưa có tài khoản? ',
                        style: TextStyle(color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Đăng ký',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
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
      ),
    );
  }
}

// ============================================================================
// REGISTER SCREEN - ĐĂNG KÝ
// ============================================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    setState(() => _errorMessage = '');

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng điền tất cả các trường');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Mật khẩu không trùng khớp');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo tài khoản thành công! Vui lòng đăng nhập'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Lỗi đăng ký');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange[400]!, Colors.orange[800]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 64,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Tạo Tài Khoản',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Smart Pet Feeder',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      hintText: 'Mật khẩu (ít nhất 6 ký tự)',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Xác nhận mật khẩu',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          );
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.orange,
                                ),
                              ),
                            )
                          : const Text(
                              'Đăng ký',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Đăng nhập',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
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
      ),
    );
  }
}

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

  // Lấy user email hiện tại
  String _getUserEmail() {
    return FirebaseAuth.instance.currentUser?.email ?? 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Pet Feeder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
        actions: [
          // Profile & Logout Menu với tên user
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Đăng xuất'),
                    content: const Text('Bạn có chắc muốn đăng xuất?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await AuthService().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tài khoản',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getUserEmail(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Đăng xuất',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_circle, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        _getUserEmail().split(
                          '@',
                        )[0], // Show username part of email
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Đặt lịch',
          ),
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
  final DatabaseReference _deviceRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://nhung-btl-tactc-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref('devices/esp32_device_01');

  double _foodLevel = 0.0;
  String _selectedAmount = 'medium'; // 'small', 'medium', 'large'
  bool _isLoading = false;

  // Subscriptions để quản lý listeners
  late StreamSubscription _foodLevelSubscription;
  late StreamSubscription _statusSubscription;

  // Mapping lượng thức ăn thành giây
  final Map<String, int> _amountToDuration = {
    'small': 2, // Ít = 2 giây
    'medium': 3, // Vừa = 3 giây
    'large': 4, // Nhiều = 4 giây
  };

  final Map<String, String> _amountLabels = {
    'small': 'Ít',
    'medium': 'Vừa',
    'large': 'Nhiều',
  };

  @override
  void initState() {
    super.initState();
    _listenToDeviceData();
  }

  void _listenToDeviceData() {
    // Real-time listen to food level
    _foodLevelSubscription = _deviceRef
        .child('sensors/food_level_percent')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.value != null && mounted) {
              try {
                double newLevel = double.parse(event.snapshot.value.toString());
                print('🔔 Food level updated: $newLevel%');
                setState(() {
                  _foodLevel = newLevel;
                });
              } catch (e) {
                print('❌ Error parsing food level: $e');
              }
            }
          },
          onError: (error) {
            print('❌ Food level listener error: $error');
          },
        );

    // Real-time listen to device status
    _statusSubscription = _deviceRef
        .child('status')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.value != null && mounted) {
              String newStatus = event.snapshot.value.toString();
              print('🔔 Status updated: $newStatus');
            }
          },
          onError: (error) {
            print('❌ Status listener error: $error');
          },
        );
  }

  @override
  void dispose() {
    // Cancel subscriptions to prevent memory leaks
    _foodLevelSubscription.cancel();
    _statusSubscription.cancel();
    super.dispose();
  }

  Future<void> sendFeedCommand() async {
    setState(() => _isLoading = true);

    try {
      int duration = _amountToDuration[_selectedAmount] ?? 3;
      await _deviceRef.child('commands/latest').set({
        'action': 'feed_now',
        'status': 'pending',
        'params': {'duration_sec': duration},
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cho ăn ${_amountLabels[_selectedAmount]}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getFoodLevelColor() {
    if (_foodLevel > 60) return Colors.green;
    if (_foodLevel > 30) return Colors.orange;
    return Colors.red;
  }

  Color _getFoodLevelStatusBgColor() {
    if (_foodLevel > 60) return Colors.green[100]!;
    if (_foodLevel > 30) return Colors.orange[100]!;
    return Colors.red[100]!;
  }

  Color _getFoodLevelStatusTextColor() {
    if (_foodLevel > 60) return Colors.green[700]!;
    if (_foodLevel > 30) return Colors.orange[700]!;
    return Colors.red[700]!;
  }

  String _getFoodLevelStatus() {
    if (_foodLevel > 60) return 'Đầy';
    if (_foodLevel > 30) return 'Trung bình';
    return 'Sắp hết';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Food Level Display
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Lượng thức ăn còn lại',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: _foodLevel / 100,
                            strokeWidth: 16,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(
                              _getFoodLevelColor(),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pets,
                              size: 48,
                              color: _getFoodLevelColor(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_foodLevel.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getFoodLevelStatusBgColor(),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getFoodLevelStatus(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getFoodLevelStatusTextColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Feeding Amount Selection
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn lượng cho ăn',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Small (2 giây)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedAmount = 'small');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedAmount == 'small'
                                    ? Colors.orange
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedAmount == 'small'
                                      ? Colors.orange
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.restaurant,
                                    color: _selectedAmount == 'small'
                                        ? Colors.white
                                        : Colors.orange,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ít',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedAmount == 'small'
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '2s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedAmount == 'small'
                                          ? Colors.white70
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Medium (3 giây)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedAmount = 'medium');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedAmount == 'medium'
                                    ? Colors.orange
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedAmount == 'medium'
                                      ? Colors.orange
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.restaurant,
                                    color: _selectedAmount == 'medium'
                                        ? Colors.white
                                        : Colors.orange,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Vừa',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedAmount == 'medium'
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '3s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedAmount == 'medium'
                                          ? Colors.white70
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Large (4 giây)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedAmount = 'large');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedAmount == 'large'
                                    ? Colors.orange
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedAmount == 'large'
                                      ? Colors.orange
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.restaurant,
                                    color: _selectedAmount == 'large'
                                        ? Colors.white
                                        : Colors.orange,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nhiều',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedAmount == 'large'
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '4s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedAmount == 'large'
                                          ? Colors.white70
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
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
            const SizedBox(height: 24),

            // Feed Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : sendFeedCommand,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.restaurant, size: 24),
                label: Text(
                  _isLoading
                      ? 'Đang cho ăn...'
                      : 'CHO ĂN ${_amountLabels[_selectedAmount]?.toUpperCase() ?? "VỪA"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 2: CAMERA (IP Webcam Integration)
// ============================================================================
class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📹 IP Webcam (Browser Embedded)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'http://192.168.0.111:8080/video',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Giao diện web của IP Webcam App',
                    style: TextStyle(color: Colors.amber, fontSize: 10),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _error.isNotEmpty
                      ? Colors.red
                      : (_isLoading ? Colors.orange : Colors.green),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _error.isNotEmpty
                      ? '● Lỗi'
                      : (_isLoading ? '● Đang tải' : '● Sẵn sàng'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // InAppWebView
        Expanded(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('http://192.168.0.111:8080/video'),
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() => _isLoading = true);
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    _isLoading = false;
                    _error = '';
                  });
                },
                onReceivedError: (controller, request, error) {
                  setState(() => _error = error.description);
                },
              ),

              if (_error.isNotEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Không thể kết nối IP Webcam',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Lỗi: $_error\n\nKiểm tra:\n1. IP Webcam app đang chạy trên điện thoại #2\n2. Wifi kết nối chung: 192.168.0.111:8080\n3. Firewall cho phép',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _error = '');
                          _webViewController?.reload();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Footer
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _webViewController?.reload();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'IP Webcam đang chạy trên điện thoại #2\nNhấn Làm mới nếu camera không xuất hiện',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.info),
                label: const Text('Thông tin'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: ĐẶT LỊCH (Schedule Management)
// ============================================================================

// ============================================================================
// TAB 3: ĐẶT LỊCH (Schedule Management)
// ============================================================================
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final DatabaseReference _deviceRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://nhung-btl-tactc-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref('devices/esp32_device_01');

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
    String amount = 'medium'; // Ít, Medium, Nhiều
    List<int> defaultDays = [2, 3, 4, 5, 6]; // Thứ 2-6 by default

    showDialog(
      context: context,
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
              const SnackBar(content: Text('Đã thêm lịch thành công!')),
            );
          }
        },
      ),
    );
  }

  Future<void> _editSchedule(String scheduleId, var schedule) async {
    showDialog(
      context: context,
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Đã cập nhật lịch!')));
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
      ).showSnackBar(const SnackBar(content: Text('Đã xóa lịch!')));
    }
  }

  Future<void> _toggleSchedule(String scheduleId, bool currentState) async {
    await _deviceRef
        .child('schedule/schedules/$scheduleId/enabled')
        .set(!currentState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: schedules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có lịch cho ăn',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                String scheduleId = schedules.keys.elementAt(index);
                var schedule = schedules[scheduleId];
                List<int> days = schedule['days'] != null
                    ? List<int>.from(schedule['days'])
                    : [2, 3, 4, 5, 6];
                final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
                String dayString = days.map((d) => dayNames[d % 7]).join(', ');

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
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: schedule['enabled']
                            ? Colors.orange[100]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.schedule,
                        color: schedule['enabled']
                            ? Colors.orange
                            : Colors.grey,
                      ),
                    ),
                    title: Text(
                      schedule['time'] ?? '--:--',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                amountLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ngày: $dayString',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: schedule['enabled'] ?? false,
                          onChanged: (value) => _toggleSchedule(
                            scheduleId,
                            schedule['enabled'] ?? false,
                          ),
                          activeColor: Colors.orange,
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Sửa'),
                              onTap: () => _editSchedule(scheduleId, schedule),
                            ),
                            PopupMenuItem(
                              child: const Text('Xóa'),
                              onTap: () => _deleteSchedule(scheduleId),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewSchedule,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Dialog for adding/editing schedules
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
  late int _selectedSeconds;

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
    // Parse initialTime - nếu có giây (HH:MM:SS) thì extract, không thì mặc định 0
    List<String> timeParts = widget.initialTime.split(':');
    if (timeParts.length == 3) {
      _selectedTime = '${timeParts[0]}:${timeParts[1]}';
      _selectedSeconds = int.tryParse(timeParts[2]) ?? 0;
    } else {
      _selectedTime = widget.initialTime;
      _selectedSeconds = 0;
    }
    _selectedAmount = widget.initialAmount;
    _selectedDays = List.from(widget.initialDays);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time picker
            Row(
              children: [
                const Text('Thời gian: '),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () async {
                    TimeOfDay? selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.parse(_selectedTime.split(':')[0]),
                        minute: int.parse(_selectedTime.split(':')[1]),
                      ),
                    );
                    if (selectedTime != null) {
                      setState(() {
                        _selectedTime =
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: Text(
                    _selectedTime,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Seconds picker
            Row(
              children: [
                const Text('Giây: '),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _selectedSeconds.toDouble(),
                    min: 0,
                    max: 59,
                    divisions: 59,
                    label: _selectedSeconds.toString().padLeft(2, '0'),
                    onChanged: (value) {
                      setState(() {
                        _selectedSeconds = value.toInt();
                      });
                    },
                  ),
                ),
                Text(_selectedSeconds.toString().padLeft(2, '0')),
              ],
            ),
            const SizedBox(height: 16),
            // Amount Selection (Ít/Vừa/Nhiều)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn lượng cho ăn:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Small (2 giây)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedAmount = 'small');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedAmount == 'small'
                                ? Colors.orange
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedAmount == 'small'
                                  ? Colors.orange
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.restaurant,
                                color: _selectedAmount == 'small'
                                    ? Colors.white
                                    : Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ít',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedAmount == 'small'
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                              ),
                              Text(
                                '2s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _selectedAmount == 'small'
                                      ? Colors.white70
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Medium (3 giây)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedAmount = 'medium');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedAmount == 'medium'
                                ? Colors.orange
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedAmount == 'medium'
                                  ? Colors.orange
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.restaurant,
                                color: _selectedAmount == 'medium'
                                    ? Colors.white
                                    : Colors.orange,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vừa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedAmount == 'medium'
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                              ),
                              Text(
                                '3s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _selectedAmount == 'medium'
                                      ? Colors.white70
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Large (4 giây)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedAmount = 'large');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedAmount == 'large'
                                ? Colors.orange
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedAmount == 'large'
                                  ? Colors.orange
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.restaurant,
                                color: _selectedAmount == 'large'
                                    ? Colors.white
                                    : Colors.orange,
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nhiều',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedAmount == 'large'
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                              ),
                              Text(
                                '4s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _selectedAmount == 'large'
                                      ? Colors.white70
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Day picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn ngày trong tuần:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    bool isSelected = _selectedDays.contains(index);
                    return FilterChip(
                      label: Text(_dayNames[index]),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(index);
                            _selectedDays.sort();
                          } else {
                            _selectedDays.remove(index);
                          }
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: Colors.orange.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.orange : Colors.black,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedDays.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng chọn ít nhất một ngày!'),
                ),
              );
              return;
            }
            // Format time thành HH:MM:SS
            String timeWithSeconds =
                '$_selectedTime:${_selectedSeconds.toString().padLeft(2, '0')}';
            widget.onSave(timeWithSeconds, _selectedAmount, _selectedDays);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Lưu', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 4: LỊCH SỬ (History)
// ============================================================================
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final DatabaseReference _deviceRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://nhung-btl-tactc-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref('devices/esp32_device_01');

  List<Map<String, dynamic>> feedingHistory = [];
  late StreamSubscription _historySubscription;

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
                  'requested_by': value['requested_by'] ?? 'unknown',
                  'success': value['success'] ?? false,
                });
              });

              // Sort by timestamp descending (newest first)
              history.sort(
                (a, b) =>
                    (b['timestamp'] as int).compareTo(a['timestamp'] as int),
              );

              setState(() {
                feedingHistory = history;
              });
            }
          },
          onError: (error) {
            print('History listener error: $error');
          },
        );
  }

  @override
  void dispose() {
    _historySubscription.cancel();
    super.dispose();
  }

  String _formatDateTime(int timestamp) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: feedingHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có lịch sử cho ăn',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: feedingHistory.length,
              itemBuilder: (context, index) {
                Map log = feedingHistory[index];
                bool success = log['success'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      success ? Icons.check_circle : Icons.error_outline,
                      color: success ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      _formatDateTime(log['timestamp'] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Thời gian: ${log['duration_sec']} giây'),
                        Text(
                          'Trạng thái: ${success ? "✓ Thành công" : "✗ Thất bại"}',
                        ),
                        Text('Yêu cầu từ: ${log['requested_by']}'),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
