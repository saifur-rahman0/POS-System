import 'package:flutter/material.dart';

String cleanErrorMessage(dynamic error) {
  if (error == null) return 'An unexpected error occurred.';
  final str = error.toString();

  if (str.contains('Connect call failed') ||
      str.contains('10061') ||
      str.contains('Connection refused') ||
      str.contains('SocketException')) {
    return 'Cannot connect to local backend server. Please ensure Docker and the backend service are running.';
  }

  if (str.contains('ProgrammingError') ||
      str.contains('does not exist') ||
      str.contains('UndefinedTable')) {
    return 'Database schema is updating or pending migration. Please verify the database setup.';
  }

  if (str.contains("type 'String' is not a subtype of type 'num'")) {
    return 'Data serialization mismatch from server. Please refresh or retry.';
  }

  if (str.contains('TimeoutException') || str.contains('timed out')) {
    return 'Request timed out. Please check local connectivity and retry.';
  }

  // Remove bulky exception prefixes
  var cleaned = str;
  if (cleaned.startsWith('Exception: ')) {
    cleaned = cleaned.substring('Exception: '.length);
  }
  return cleaned;
}

class PosErrorCard extends StatefulWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String title;
  final IconData icon;

  const PosErrorCard({
    super.key,
    required this.error,
    this.onRetry,
    this.title = 'Unable to Load Data',
    this.icon = Icons.cloud_off_outlined,
  });

  @override
  State<PosErrorCard> createState() => _PosErrorCardState();
}

class _PosErrorCardState extends State<PosErrorCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final friendlyMsg = cleanErrorMessage(widget.error);
    final rawError = widget.error?.toString() ?? '';

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 32,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              friendlyMsg,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _showDetails = !_showDetails),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showDetails ? 'Hide technical diagnostics' : 'Show technical diagnostics',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SelectableText(
                  rawError,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
