import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/settings/domain/models/hardware_settings.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';

class HardwareTab extends ConsumerStatefulWidget {
  const HardwareTab({super.key});

  @override
  ConsumerState<HardwareTab> createState() => _HardwareTabState();
}

class _HardwareTabState extends ConsumerState<HardwareTab> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _printerNameController;
  final TextEditingController _scannerTestController = TextEditingController();

  String? _lastScannedBarcode;
  DateTime? _lastScanTime;
  bool _isTestingPrint = false;
  bool _isKickingDrawer = false;

  @override
  void initState() {
    super.initState();
    final hw = ref.read(hardwareSettingsProvider);
    _ipController = TextEditingController(text: hw.printerIp);
    _portController = TextEditingController(text: hw.printerPort.toString());
    _printerNameController = TextEditingController(text: hw.printerName);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _printerNameController.dispose();
    _scannerTestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hw = ref.watch(hardwareSettingsProvider);
    final hwNotifier = ref.read(hardwareSettingsProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: ESC/POS Thermal Receipt Printer
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print, color: Color(0xFF0F766E), size: 28),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ESC/POS Thermal Receipt Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Configure TCP Network, USB Spooler, or File Simulation drivers', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6FFFA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hw.printerMode == PrinterConnectionMode.networkTcp
                              ? 'TCP Socket Mode'
                              : hw.printerMode == PrinterConnectionMode.windowsSpooler
                                  ? 'Windows Spooler'
                                  : 'File Simulator',
                          style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Connection Mode Segmented Button
                  const Text('Printer Connection Type', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<PrinterConnectionMode>(
                    segments: const [
                      ButtonSegment(
                        value: PrinterConnectionMode.networkTcp,
                        label: Text('Network TCP Socket'),
                        icon: Icon(Icons.wifi),
                      ),
                      ButtonSegment(
                        value: PrinterConnectionMode.windowsSpooler,
                        label: Text('Windows USB Spooler'),
                        icon: Icon(Icons.usb),
                      ),
                      ButtonSegment(
                        value: PrinterConnectionMode.fileSimulator,
                        label: Text('Spool File Simulator'),
                        icon: Icon(Icons.sim_card),
                      ),
                    ],
                    selected: {hw.printerMode},
                    onSelectionChanged: (set) {
                      hwNotifier.updateSettings(hw.copyWith(printerMode: set.first));
                    },
                  ),
                  const SizedBox(height: 16),

                  if (hw.printerMode == PrinterConnectionMode.networkTcp) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                              labelText: 'Printer IP Address (e.g. 192.168.1.200)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lan),
                            ),
                            onChanged: (v) {
                              hwNotifier.updateSettings(hw.copyWith(printerIp: v.trim()));
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port (Default: 9100)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final port = int.tryParse(v) ?? 9100;
                              hwNotifier.updateSettings(hw.copyWith(printerPort: port));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else if (hw.printerMode == PrinterConnectionMode.windowsSpooler) ...[
                    TextFormField(
                      controller: _printerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Installed Windows Printer Device Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.devices),
                        hintText: 'e.g. POS-80-Thermal',
                      ),
                      onChanged: (v) {
                        hwNotifier.updateSettings(hw.copyWith(printerName: v.trim()));
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Paper Size & Options
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Paper Roll Width', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SegmentedButton<ReceiptPaperSize>(
                              segments: const [
                                ButtonSegment(value: ReceiptPaperSize.mm80, label: Text('80mm Standard')),
                                ButtonSegment(value: ReceiptPaperSize.mm58, label: Text('58mm Compact')),
                              ],
                              selected: {hw.paperSize},
                              onSelectionChanged: (set) {
                                hwNotifier.updateSettings(hw.copyWith(paperSize: set.first));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Auto-cut receipt paper'),
                              subtitle: const Text('Sends GS V partial cut byte command'),
                              value: hw.autoCutPaper,
                              activeThumbColor: const Color(0xFF0F766E),
                              onChanged: (v) {
                                hwNotifier.updateSettings(hw.copyWith(autoCutPaper: v));
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Kick cash drawer on checkout'),
                              subtitle: const Text('Sends ESC p pulse pin 2 command'),
                              value: hw.kickCashDrawer,
                              activeThumbColor: const Color(0xFF0F766E),
                              onChanged: (v) {
                                hwNotifier.updateSettings(hw.copyWith(kickCashDrawer: v));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons for Printer
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _isTestingPrint
                            ? null
                            : () async {
                                setState(() => _isTestingPrint = true);
                                final ok = await hwNotifier.testPrintReceipt();
                                if (context.mounted) {
                                  setState(() => _isTestingPrint = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Diagnostic test slip sent to printer successfully'
                                          : 'Failed to send test slip to printer'),
                                      backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red,
                                    ),
                                  );
                                }
                              },
                        icon: _isTestingPrint
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.receipt),
                        label: const Text('Print Diagnostic Slip'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _isKickingDrawer
                            ? null
                            : () async {
                                setState(() => _isKickingDrawer = true);
                                final ok = await hwNotifier.testKickCashDrawer();
                                if (context.mounted) {
                                  setState(() => _isKickingDrawer = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Cash drawer kick pulse sent'
                                          : 'Failed to trigger cash drawer kick'),
                                      backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.inbox),
                        label: const Text('Open Cash Drawer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Barcode Scanner Wedge Listener
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Color(0xFF0F766E), size: 28),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hardware Barcode Scanner Wedge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('USB & Bluetooth CCD/Laser keyboard emulation listener', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inter-keystroke threshold: ${hw.scannerLatencyThresholdMs}ms',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hardware barcode scanners burst characters rapidly (< 65ms per stroke). Keystrokes faster than this threshold are captured directly into the cart without requiring field focus.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Slider(
                              value: hw.scannerLatencyThresholdMs.toDouble(),
                              min: 30,
                              max: 120,
                              divisions: 9,
                              label: '${hw.scannerLatencyThresholdMs} ms',
                              activeColor: const Color(0xFF0F766E),
                              onChanged: (val) {
                                hwNotifier.updateSettings(hw.copyWith(scannerLatencyThresholdMs: val.toInt()));
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Beep on scan detection'),
                              subtitle: const Text('Play confirmation tone when a barcode is captured'),
                              value: hw.enableBeepOnScan,
                              activeThumbColor: const Color(0xFF0F766E),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) {
                                hwNotifier.updateSettings(hw.copyWith(enableBeepOnScan: v));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Live Scanner Testing Area', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text('Scan any physical product barcode to test detection:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _scannerTestController,
                                decoration: InputDecoration(
                                  hintText: 'Scan or type barcode here...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _scannerTestController.clear(),
                                  ),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    setState(() {
                                      _lastScannedBarcode = val.trim();
                                      _lastScanTime = DateTime.now();
                                    });
                                  }
                                },
                              ),
                              if (_lastScannedBarcode != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green.shade800),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Captured: $_lastScannedBarcode',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                            ),
                                            Text(
                                              'Detected at: ${_lastScanTime?.toLocal().toString().substring(11, 19)}',
                                              style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
