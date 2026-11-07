import '../../../../core/utils/parsers.dart';

class BackupRecordModel {
  final String id;
  final String backupType; // MANUAL, SCHEDULED, AUTO_PRE_UPGRADE
  final String fileName;
  final int sizeBytes;
  final String checksum;
  final String status; // COMPLETED, FAILED, RESTORING
  final String? errorMessage;
  final DateTime createdAt;

  const BackupRecordModel({
    required this.id,
    required this.backupType,
    required this.fileName,
    required this.sizeBytes,
    required this.checksum,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  factory BackupRecordModel.fromJson(Map<String, dynamic> json) {
    return BackupRecordModel(
      id: json['id'] as String,
      backupType: json['backup_type']?.toString() ?? 'MANUAL',
      fileName: json['file_name']?.toString() ?? 'backup.json.gz',
      sizeBytes: parseInt(json['size_bytes']),
      checksum: json['checksum']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      errorMessage: json['error_message']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class BackupRestoreResultModel {
  final String backupId;
  final String fileName;
  final String status;
  final int tablesVerified;
  final int recordsCount;
  final DateTime restoredAt;
  final String message;

  const BackupRestoreResultModel({
    required this.backupId,
    required this.fileName,
    required this.status,
    required this.tablesVerified,
    required this.recordsCount,
    required this.restoredAt,
    required this.message,
  });

  factory BackupRestoreResultModel.fromJson(Map<String, dynamic> json) {
    return BackupRestoreResultModel(
      backupId: json['backup_id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'RESTORED',
      tablesVerified: parseInt(json['tables_verified']),
      recordsCount: parseInt(json['records_count']),
      restoredAt: json['restored_at'] != null
          ? DateTime.tryParse(json['restored_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      message: json['message']?.toString() ?? '',
    );
  }
}
