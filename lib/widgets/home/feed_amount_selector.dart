import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

/// ============================================================================
/// FEED AMOUNT SELECTOR - Playful Button Selection
/// ============================================================================

class FeedAmountSelector extends StatefulWidget {
  final String initialAmount;
  final ValueChanged<String> onAmountChanged;
  final bool isEnabled;

  const FeedAmountSelector({
    Key? key,
    required this.initialAmount,
    required this.onAmountChanged,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  State<FeedAmountSelector> createState() => _FeedAmountSelectorState();
}

class _FeedAmountSelectorState extends State<FeedAmountSelector> {
  late String _selectedAmount;

  @override
  void initState() {
    super.initState();
    _selectedAmount = widget.initialAmount;
  }

  void _selectAmount(String amount) {
    if (!widget.isEnabled) return;

    setState(() {
      _selectedAmount = amount;
    });
    widget.onAmountChanged(amount);
  }

  Widget _buildAmountButton(
    String amount,
    String label,
    String emoji,
    int sizeIndex,
  ) {
    final isSelected = _selectedAmount == amount;
    final sizes = [32, 42, 52]; // Icon sizes
    final iconSize = sizes[sizeIndex];

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectAmount(amount),
        child: AnimatedContainer(
          duration: Duration(milliseconds: AppConstants.durationQuick),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? (amount == 'small'
                      ? LinearGradient(
                          colors: [AppColors.primary, Color(0xFF3498DB)],
                        )
                      : amount == 'medium'
                      ? AppColors.secondaryGradient
                      : LinearGradient(
                          colors: [AppColors.accent, Color(0xFF5DCDA0)],
                        ))
                : null,
            color: isSelected ? null : AppColors.greyLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: isSelected
                  ? (amount == 'small'
                        ? AppColors.primary
                        : amount == 'medium'
                        ? AppColors.secondary
                        : AppColors.accent)
                  : Colors.transparent,
              width: 3,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          (amount == 'small'
                                  ? AppColors.primary
                                  : amount == 'medium'
                                  ? AppColors.secondary
                                  : AppColors.accent)
                              .withOpacity(0.4),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: Duration(milliseconds: AppConstants.durationQuick),
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: iconSize.toDouble()),
                ),
              ),
              SizedBox(height: 6),
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.greyDark,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2),
              // Duration
              Text(
                '${amountToDuration[amount]}s',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.white70 : AppColors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: EdgeInsets.only(bottom: AppConstants.paddingSmall),
            child: Text(
              '🍽️ Chọn lượng cho ăn',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.greyDark,
              ),
            ),
          ),
          // Buttons
          Opacity(
            opacity: widget.isEnabled ? 1.0 : 0.6,
            child: Row(
              children: [
                _buildAmountButton('small', 'Ít', '🥩', 0),
                SizedBox(width: AppConstants.paddingSmall),
                _buildAmountButton('medium', 'Vừa', '🍖', 1),
                SizedBox(width: AppConstants.paddingSmall),
                _buildAmountButton('large', 'Nhiều', '🍗', 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
