import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

/// ============================================================================
/// FOOD LEVEL CIRCLE - Playful Circular Indicator
/// ============================================================================

class FoodLevelCircle extends StatefulWidget {
  final double foodLevel;
  final Duration animationDuration;

  const FoodLevelCircle({
    Key? key,
    required this.foodLevel,
    this.animationDuration = const Duration(milliseconds: 800),
  }) : super(key: key);

  @override
  State<FoodLevelCircle> createState() => _FoodLevelCircleState();
}

class _FoodLevelCircleState extends State<FoodLevelCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: widget.foodLevel / 100).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(FoodLevelCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foodLevel != widget.foodLevel) {
      // Reset animation without recreating controller (avoids multiple ticker error)
      _animationController.reset();

      // Create new animation with updated foodLevel
      _animation = Tween<double>(begin: 0, end: widget.foodLevel / 100).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );

      _animationController.forward();
    }
  }

  Color _getLevelColor() {
    if (widget.foodLevel > 60) return AppColors.accent; // Mint Green
    if (widget.foodLevel > 30) return AppColors.secondary; // Soft Orange
    return AppColors.error; // Red
  }

  String _getLevelStatus() {
    if (widget.foodLevel > 75) return 'Đầy';
    if (widget.foodLevel > 50) return 'Trung bình';
    if (widget.foodLevel > 25) return 'Ít';
    if (widget.foodLevel > 0) return 'Sắp hết';
    return 'Sắp hết';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular progress indicator
            Container(
              height: 280,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle (outer ring)
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),

                  // Animated progress circle
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CustomPaint(
                      painter: _CircleProgressPainter(
                        progress: _animation.value,
                        backgroundColor: AppColors.greyLight,
                        progressColor: _getLevelColor(),
                        strokeWidth: 18,
                      ),
                    ),
                  ),

                  // Center content - Pet icon and percentage only
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cute Pet Icon
                      Image.asset(
                        'assets/icon/pets.png',
                        width: 56,
                        height: 56,
                      ),
                      SizedBox(height: 6),

                      // Percentage
                      Text(
                        '${widget.foodLevel.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.greyDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status label outside circle - no overlap
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: _getLevelColor() == AppColors.accent
                    ? LinearGradient(
                        colors: [AppColors.accent, AppColors.accentPink],
                      )
                    : _getLevelColor() == AppColors.secondary
                    ? AppColors.secondaryGradient
                    : LinearGradient(
                        colors: [AppColors.error, Color(0xFFC0392B)],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getLevelColor().withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _getLevelStatus(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

/// Custom painter for circular progress
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}
