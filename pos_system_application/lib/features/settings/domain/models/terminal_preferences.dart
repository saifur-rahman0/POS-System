class TerminalPreferencesModel {
  final String terminalName;
  final String deviceId;
  final int autoRefreshIntervalSeconds; // 0 for disabled, 15, 30, 60
  final bool soundEffectsEnabled;
  final bool isDarkMode;

  const TerminalPreferencesModel({
    this.terminalName = 'Main Register Terminal 01',
    this.deviceId = 'DEV-REG-01',
    this.autoRefreshIntervalSeconds = 30,
    this.soundEffectsEnabled = true,
    this.isDarkMode = false,
  });

  TerminalPreferencesModel copyWith({
    String? terminalName,
    String? deviceId,
    int? autoRefreshIntervalSeconds,
    bool? soundEffectsEnabled,
    bool? isDarkMode,
  }) {
    return TerminalPreferencesModel(
      terminalName: terminalName ?? this.terminalName,
      deviceId: deviceId ?? this.deviceId,
      autoRefreshIntervalSeconds: autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}
