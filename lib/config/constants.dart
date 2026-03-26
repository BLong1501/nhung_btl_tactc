/// ============================================================================
/// APP CONSTANTS
/// ============================================================================

class AppConstants {
  // Sizing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Animation Durations (milliseconds)
  static const int durationQuick = 200;
  static const int durationMedium = 300;
  static const int durationSlow = 500;

  // Button Disable Duration (milliseconds)
  static const int buttonDisableDuration = 3000;

  // Firebase Paths
  static const String deviceId = 'esp32_device_01';
  static const String devicePath = 'devices/$deviceId';
  static const String foodLevelPath = '$devicePath/sensors/food_level_percent';
  static const String sensorPath = '$devicePath/sensors';
  static const String commandPath = '$devicePath/commands/latest';
  static const String schedulePath = '$devicePath/schedule/schedules';
  static const String historyPath = '$devicePath/history/feeding_log';

  // Recent History
  static const int recentHistoryCount = 4;
}

// Feed Amount Mapping
const Map<String, int> amountToDuration = {
  'small': 2, // Ít
  'medium': 3, // Vừa
  'large': 4, // Nhiều
};

const Map<String, String> amountLabels = {
  'small': 'Ít',
  'medium': 'Vừa',
  'large': 'Nhiều',
};

const Map<String, String> amountEmojis = {
  'small': '🍗',
  'medium': '🍖',
  'large': '🍗🍖',
};
