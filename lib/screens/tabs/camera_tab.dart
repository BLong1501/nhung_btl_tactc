import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';

const String CAMERA_URL = 'http://192.168.0.111:8080/video';

class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String _error = '';
  bool _showControls = false;
  bool _showInfoPanel = true;
  bool _isConnected = false;

  late AnimationController _controlsAnimationController;
  Timer? _loadingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _startLoadingTimeout();
  }

  void _startLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoading && _error.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Timeout - Camera không phản hồi (5s)';
          _isConnected = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controlsAnimationController.dispose();
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _controlsAnimationController.forward();
      } else {
        _controlsAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main Camera View (Full Screen)
          GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                // Camera WebView - FULL SCREEN
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(CAMERA_URL)),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    _isConnected = true;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _error = '';
                    });
                    _startLoadingTimeout();
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      _isLoading = false;
                      _isConnected = true;
                      _error = '';
                    });
                    _loadingTimeoutTimer?.cancel();
                  },
                  onReceivedError: (controller, request, error) {
                    setState(() {
                      _error = error.description;
                      _isLoading = false;
                      _isConnected = false;
                    });
                    _loadingTimeoutTimer?.cancel();
                  },
                ),

                // Loading Overlay
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ShimmerLoading(
                            width: 100,
                            height: 100,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Đang kết nối camera...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),





                // Floating Eye Icon (Top Right - when sidebar is hidden)
                if (!_showInfoPanel && !_showControls)
                  Positioned(
                    top: 12,
                    right: 120,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange[600],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _showInfoPanel = true);
                          },
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                  ),

                // Controls Bottom Bar (Tap to Show/Hide)
                if (_showControls)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _controlsAnimationController,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0),
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ControlButton(
                              icon: Icons.refresh,
                              label: 'Làm mới',
                              onPressed: () {
                                _webViewController?.reload();
                                _toggleControls();
                              },
                            ),
                            _ControlButton(
                              icon: Icons.info_outline,
                              label: 'Thông tin',
                              onPressed: () {
                                setState(() => _showInfoPanel = true);
                                _toggleControls();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Sidebar Overlay (Right)
          if (_showInfoPanel && !_showControls)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _controlsAnimationController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    border: Border(
                      left: BorderSide(color: Colors.orange[400]!, width: 2),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Eye Icon (Top - to hide sidebar)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.visibility_off,
                              color: Colors.white70,
                              size: 20,
                            ),
                            tooltip: 'Ẩn thông tin',
                            onPressed: () {
                              setState(() => _showInfoPanel = false);
                            },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),

                        // Info Items
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SidebarItem(
                                icon: Icons.videocam,
                                label: 'Camera',
                                value: 'IP Webcam',
                              ),
                              const SizedBox(height: 16),
                              _SidebarItem(
                                icon: Icons.language,
                                label: 'URL',
                                value: '192.168...',
                                fontSize: 10,
                              ),
                              const SizedBox(height: 16),
                              _SidebarItem(
                                icon: Icons.cloud_done,
                                label: 'Status',
                                value: _error.isNotEmpty
                                    ? 'Error'
                                    : (_isLoading ? 'Loading' : 'Online'),
                              ),
                              const SizedBox(height: 16),
                              _SidebarItem(
                                icon: Icons.router,
                                label: 'Network',
                                value: 'Connected',
                                valueColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

    );
  }


}

// ============================================================================
// Custom Widgets for Camera Tab
// ============================================================================

class _ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerLoading({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(
                -1.0 - (_controller.value * 2),
                _controller.value,
              ),
              end: Alignment(1.0 - (_controller.value * 2), _controller.value),
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final double fontSize;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.orange[400], size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
