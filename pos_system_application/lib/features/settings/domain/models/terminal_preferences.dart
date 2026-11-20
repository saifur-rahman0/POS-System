class TerminalPreferencesModel {
  final String terminalName;
  final String deviceId;
  final int autoRefreshIntervalSeconds; // 0 for disabled, 15, 30, 60
  final bool soundEffectsEnabled;
  final bool isDarkMode;
  final bool isPosTableView; // false for Grid, true for Table

  const TerminalPreferencesModel({
    this.terminalName = 'Main Register Terminal 01',
    this.deviceId = 'DEV-REG-01',
    this.autoRefreshIntervalSeconds = 30,
    this.soundEffectsEnabled = true,
    this.isDarkMode = false,
    this.isPosTableView = false,
  });

  TerminalPreferencesModel copyWith({
    String? terminalName,
    String? deviceId,
    int? autoRefreshIntervalSeconds,
    bool? soundEffectsEnabled,
    bool? isDarkMode,
    bool? isPosTableView,
  }) {
    return TerminalPreferencesModel(
      terminalName: terminalName ?? this.terminalName,
      deviceId: deviceId ?? this.deviceId,
      autoRefreshIntervalSeconds: autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isPosTableView: isPosTableView ?? this.isPosTableView,
    );
  }

  Map<String, dynamic> toJson() => {
        'terminalName': terminalName,
        'deviceId': deviceId,
        'autoRefreshIntervalSeconds': autoRefreshIntervalSeconds,
        'soundEffectsEnabled': soundEffectsEnabled,
        'isDarkMode': isDarkMode,
        'isPosTableView': isPosTableView,
      };

  factory TerminalPreferencesModel.fromJson(Map<String, dynamic> json) =>
      TerminalPreferencesModel(
        terminalName: json['terminalName'] as String? ?? 'Main Register Terminal 01',
        deviceId: json['deviceId'] as String? ?? 'DEV-REG-01',
        autoRefreshIntervalSeconds:
            (json['autoRefreshIntervalSeconds'] as num?)?.toInt() ?? 30,
        soundEffectsEnabled: json['soundEffectsEnabled'] as bool? ?? true,
        isDarkMode: json['isDarkMode'] as bool? ?? false,
        isPosTableView: json['isPosTableView'] as bool? ?? false,
      );
}
