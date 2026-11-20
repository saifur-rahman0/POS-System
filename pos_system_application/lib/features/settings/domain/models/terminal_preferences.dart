class TerminalPreferencesModel {
  final String terminalName;
  final String deviceId;
  final int autoRefreshIntervalSeconds; // 0 for disabled, 15, 30, 60
  final bool soundEffectsEnabled;
  final bool isDarkMode;
  final bool isPosTableView; // false for Grid, true for Table
  final double cartPanelWidth;
  final Map<String, double> tableColumnWidths;

  const TerminalPreferencesModel({
    this.terminalName = 'Main Register Terminal 01',
    this.deviceId = 'DEV-REG-01',
    this.autoRefreshIntervalSeconds = 30,
    this.soundEffectsEnabled = true,
    this.isDarkMode = false,
    this.isPosTableView = false,
    this.cartPanelWidth = 380.0,
    this.tableColumnWidths = const {},
  });

  TerminalPreferencesModel copyWith({
    String? terminalName,
    String? deviceId,
    int? autoRefreshIntervalSeconds,
    bool? soundEffectsEnabled,
    bool? isDarkMode,
    bool? isPosTableView,
    double? cartPanelWidth,
    Map<String, double>? tableColumnWidths,
  }) {
    return TerminalPreferencesModel(
      terminalName: terminalName ?? this.terminalName,
      deviceId: deviceId ?? this.deviceId,
      autoRefreshIntervalSeconds: autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isPosTableView: isPosTableView ?? this.isPosTableView,
      cartPanelWidth: cartPanelWidth ?? this.cartPanelWidth,
      tableColumnWidths: tableColumnWidths ?? this.tableColumnWidths,
    );
  }

  Map<String, dynamic> toJson() => {
        'terminalName': terminalName,
        'deviceId': deviceId,
        'autoRefreshIntervalSeconds': autoRefreshIntervalSeconds,
        'soundEffectsEnabled': soundEffectsEnabled,
        'isDarkMode': isDarkMode,
        'isPosTableView': isPosTableView,
        'cartPanelWidth': cartPanelWidth,
        'tableColumnWidths': tableColumnWidths,
      };

  factory TerminalPreferencesModel.fromJson(Map<String, dynamic> json) {
    Map<String, double> parsedWidths = {};
    if (json['tableColumnWidths'] is Map) {
      (json['tableColumnWidths'] as Map).forEach((k, v) {
        if (v is num) parsedWidths[k.toString()] = v.toDouble();
      });
    }
    return TerminalPreferencesModel(
      terminalName: json['terminalName'] as String? ?? 'Main Register Terminal 01',
      deviceId: json['deviceId'] as String? ?? 'DEV-REG-01',
      autoRefreshIntervalSeconds:
          (json['autoRefreshIntervalSeconds'] as num?)?.toInt() ?? 30,
      soundEffectsEnabled: json['soundEffectsEnabled'] as bool? ?? true,
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      isPosTableView: json['isPosTableView'] as bool? ?? false,
      cartPanelWidth: (json['cartPanelWidth'] as num?)?.toDouble() ?? 380.0,
      tableColumnWidths: parsedWidths,
    );
  }
}
