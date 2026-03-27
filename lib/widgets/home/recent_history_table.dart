import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

/// ============================================================================
/// RECENT HISTORY TABLE - Display recent feedings in table format
/// ============================================================================

class RecentHistoryTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const RecentHistoryTable({Key? key, required this.items}) : super(key: key);

  String _getAmountLabel(String amount) {
    switch (amount) {
      case 'small':
        return 'Ít';
      case 'large':
        return 'Nhiều';
      default:
        return 'Vừa';
    }
  }

  Color _getAmountColor(String amount) {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!, width: 1),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> item = entry.value;
            bool isAlternate = index.isEven;

            return Container(
              decoration: BoxDecoration(
                color: isAlternate ? Colors.white : Colors.grey[50],
                border: index < items.length - 1
                    ? Border(
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Thời gian (bên trái)
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        item['time'] ?? '--:--',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: AppColors.greyDark,
                        ),
                      ),
                    ),
                  ),

                  // Vertical divider
                  Container(height: 40, width: 1, color: Colors.grey[300]),

                  // Mức (bên phải)
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getAmountColor(
                            item['amount'] ?? 'medium',
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getAmountColor(
                              item['amount'] ?? 'medium',
                            ).withOpacity(0.5),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _getAmountLabel(item['amount'] ?? 'medium'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: _getAmountColor(item['amount'] ?? 'medium'),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
