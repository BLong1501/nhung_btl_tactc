import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

/// ============================================================================
/// FEED BUTTON - Playful Feed Action Button with Animated Checkmark
/// ============================================================================

class FeedButton extends StatefulWidget {
  final String selectedAmount;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isFeeding;
  final bool showSuccess;

  const FeedButton({
    Key? key,
    required this.selectedAmount,
    required this.onPressed,
    this.isLoading = false,
    this.isFeeding = false,
    this.showSuccess = false,
  }) : super(key: key);

  @override
  State<FeedButton> createState() => _FeedButtonState();
}

class _FeedButtonState extends State<FeedButton> with TickerProviderStateMixin {
  late AnimationController _checkmarkController;
  late Animation<double> _checkmarkScale;
  late Animation<double> _checkmarkOpacity;

  @override
  void initState() {
    super.initState();
    _setupCheckmarkAnimation();
  }

  void _setupCheckmarkAnimation() {
    _checkmarkController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _checkmarkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkmarkController, curve: Curves.elasticOut),
    );

    _checkmarkOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _checkmarkController,
        curve: Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didUpdateWidget(FeedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSuccess && !oldWidget.showSuccess) {
      _checkmarkController.forward(from: 0);
    }
  }

  String _getButtonText() {
    if (widget.showSuccess) return '✓ Thành công!';
    if (widget.isFeeding) return 'Feeding...';
    return 'CHO ĂN ${amountLabels[widget.selectedAmount]?.toUpperCase() ?? "VỪA"}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Button
          AnimatedOpacity(
            opacity: widget.isFeeding ? 0.6 : 1.0,
            duration: Duration(milliseconds: AppConstants.durationQuick),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.foodLevelGradient,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(
                      widget.isFeeding ? 0.2 : 0.4,
                    ),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isFeeding || widget.showSuccess
                      ? null
                      : widget.onPressed,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        AnimatedSwitcher(
                          duration: Duration(
                            milliseconds: AppConstants.durationQuick,
                          ),
                          child: widget.isFeeding
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text('🍽️', style: TextStyle(fontSize: 20)),
                        ),
                        SizedBox(width: 12),

                        // Text
                        Text(
                          _getButtonText(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Animated Checkmark Overlay
          if (widget.showSuccess)
            ScaleTransition(
              scale: _checkmarkScale,
              child: FadeTransition(
                opacity: _checkmarkOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success.withOpacity(0.9),
                        Color(0xFF27AE60).withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusLarge,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _checkmarkController.dispose();
    super.dispose();
  }
}
