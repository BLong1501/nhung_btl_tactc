import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

/// ============================================================================
/// RECENT HISTORY ITEM - Display recent feeding
/// ============================================================================

class RecentHistoryItem extends StatelessWidget {
  final String time;
  final String amount;
  final double foodConsumed;

  const RecentHistoryItem({
    Key? key,
    required this.time,
    required this.amount,
    required this.foodConsumed,
  }) : super(key: key);

  Icon _getAmountIcon() {
    switch (amount) {
      case 'small':
        return Icon(Icons.restaurant, color: AppColors.primary, size: 20);
      case 'large':
        return Icon(Icons.restaurant, color: AppColors.accent, size: 24);
      default: // medium
        return Icon(Icons.restaurant, color: AppColors.secondary, size: 22);
    }
  }

  Color _getAmountColor() {
    switch (amount) {
      case 'small':
        return AppColors.primary;
      case 'large':
        return AppColors.accent;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppConstants.paddingSmall),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getAmountColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border(left: BorderSide(color: _getAmountColor(), width: 4)),
      ),
      child: Row(
        children: [
          // Icon background
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getAmountColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: _getAmountIcon(),
          ),
          SizedBox(width: AppConstants.paddingMedium),

          // Time + Amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.greyDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  amountLabels[amount] ?? 'Vừa',
                  style: TextStyle(
                    fontSize: 11,
                    color: _getAmountColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Food consumed badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getAmountColor().withOpacity(0.8),
                  _getAmountColor().withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '-${foodConsumed.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
