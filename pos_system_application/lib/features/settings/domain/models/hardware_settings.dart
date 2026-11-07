enum PrinterConnectionMode {
  networkTcp,
  windowsSpooler,
  fileSimulator,
}

enum ReceiptPaperSize {
  mm80,
  mm58,
}

class HardwareSettingsModel {
  final PrinterConnectionMode printerMode;
  final String printerIp;
  final int printerPort;
  final String printerName;
  final ReceiptPaperSize paperSize;
  final bool autoCutPaper;
  final bool kickCashDrawer;
  final int scannerLatencyThresholdMs;
  final bool enableBeepOnScan;

  const HardwareSettingsModel({
    this.printerMode = PrinterConnectionMode.fileSimulator,
    this.printerIp = '192.168.1.200',
    this.printerPort = 9100,
    this.printerName = 'POS-80-Thermal',
    this.paperSize = ReceiptPaperSize.mm80,
    this.autoCutPaper = true,
    this.kickCashDrawer = true,
    this.scannerLatencyThresholdMs = 65,
    this.enableBeepOnScan = true,
  });

  HardwareSettingsModel copyWith({
    PrinterConnectionMode? printerMode,
    String? printerIp,
    int? printerPort,
    String? printerName,
    ReceiptPaperSize? paperSize,
    bool? autoCutPaper,
    bool? kickCashDrawer,
    int? scannerLatencyThresholdMs,
    bool? enableBeepOnScan,
  }) {
    return HardwareSettingsModel(
      printerMode: printerMode ?? this.printerMode,
      printerIp: printerIp ?? this.printerIp,
      printerPort: printerPort ?? this.printerPort,
      printerName: printerName ?? this.printerName,
      paperSize: paperSize ?? this.paperSize,
      autoCutPaper: autoCutPaper ?? this.autoCutPaper,
      kickCashDrawer: kickCashDrawer ?? this.kickCashDrawer,
      scannerLatencyThresholdMs: scannerLatencyThresholdMs ?? this.scannerLatencyThresholdMs,
      enableBeepOnScan: enableBeepOnScan ?? this.enableBeepOnScan,
    );
  }
}
