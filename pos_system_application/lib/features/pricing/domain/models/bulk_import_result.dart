class BulkImportErrorModel {
  final int row;
  final String? field;
  final String message;

  const BulkImportErrorModel({
    required this.row,
    this.field,
    required this.message,
  });

  factory BulkImportErrorModel.fromJson(Map<String, dynamic> json) {
    return BulkImportErrorModel(
      row: json['row'] as int? ?? 0,
      field: json['field']?.toString(),
      message: json['message']?.toString() ?? '',
    );
  }
}

class BulkImportResultModel {
  final int totalRows;
  final int createdCount;
  final int updatedCount;
  final int errorCount;
  final List<BulkImportErrorModel> errors;

  const BulkImportResultModel({
    required this.totalRows,
    required this.createdCount,
    required this.updatedCount,
    required this.errorCount,
    this.errors = const [],
  });

  factory BulkImportResultModel.fromJson(Map<String, dynamic> json) {
    return BulkImportResultModel(
      totalRows: json['total_rows'] as int? ?? 0,
      createdCount: json['created_count'] as int? ?? 0,
      updatedCount: json['updated_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => BulkImportErrorModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
