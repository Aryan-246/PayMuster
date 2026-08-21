import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/paymuster_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/document_api_client.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  List<StaffDocumentSummary> _documents = const [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _openingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final documents = await ref.read(documentApiClientProvider).listMine();
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _selectAndUpload({StaffDocumentSummary? resubmissionOf}) async {
    if (_isUploading) return;

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showError('The selected document is empty.');
        return;
      }
      final extension = _extensionFor(file.name);

      final mimeType = _mimeTypeFor(extension);
      if (mimeType == null) {
        _showError('Select a PDF, JPEG, or PNG document.');
        return;
      }

      final metadata = resubmissionOf == null
          ? await _requestUploadMetadata()
          : _UploadMetadata(resubmissionOf.type, resubmissionOf.expiryDate);
      if (metadata == null || !mounted) return;

      setState(() => _isUploading = true);
      await ref
          .read(documentApiClientProvider)
          .upload(
            bytes: bytes,
            filename: _safeHeaderFilename(file.name, extension),
            mimeType: mimeType,
            documentType: metadata.documentType,
            expiryDate: metadata.expiryDate,
            parentDocumentId: resubmissionOf?.id,
          );
      if (!mounted) return;
      await _loadDocuments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document submitted for review.')),
      );
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<_UploadMetadata?> _requestUploadMetadata() async {
    final typeController = TextEditingController();
    DateTime? expiryDate;
    String? validationError;

    final metadata = await showDialog<_UploadMetadata>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Document details'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: typeController,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Document type',
                    hintText: 'Example: Aadhaar card',
                    errorText: validationError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PMSpacing.s2),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: expiryDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 3650),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 36500)),
                    );
                    if (selected != null) {
                      setDialogState(() => expiryDate = selected);
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    expiryDate == null
                        ? 'Add expiry date'
                        : 'Expiry: ${_formatDate(expiryDate!)}',
                  ),
                ),
                if (expiryDate != null)
                  TextButton.icon(
                    onPressed: () => setDialogState(() => expiryDate = null),
                    icon: const Icon(Icons.clear),
                    label: const Text('Remove expiry date'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final documentType = typeController.text.trim();
                final isValid = RegExp(
                  r'^[a-zA-Z0-9][a-zA-Z0-9 ()_./-]{1,79}$',
                ).hasMatch(documentType);
                if (!isValid) {
                  setDialogState(() {
                    validationError =
                        'Use 2-80 letters, numbers, spaces, or () _ . / -';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _UploadMetadata(documentType, expiryDate),
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
    typeController.dispose();
    return metadata;
  }

  Future<void> _openDocument(StaffDocumentSummary document) async {
    if (_openingId != null) return;
    setState(() => _openingId = document.id);
    try {
      final uri = await ref
          .read(documentApiClientProvider)
          .createViewUrl(document.id);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw Exception('The document could not be opened on this device.');
      }
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception: '), '');
  }

  String? _extensionFor(String filename) {
    final separatorIndex = filename.lastIndexOf('.');
    if (separatorIndex <= 0 || separatorIndex == filename.length - 1) {
      return null;
    }
    return filename.substring(separatorIndex + 1).toLowerCase();
  }

  String? _mimeTypeFor(String? extension) {
    return switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }

  String _safeHeaderFilename(String filename, String? extension) {
    final safe = filename
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '_')
        .replaceAll(RegExp(r'[\\/]'), '_')
        .trim();
    if (safe.isNotEmpty) {
      return safe.length > 160 ? safe.substring(0, 160) : safe;
    }
    return 'document.${extension?.toLowerCase() ?? 'bin'}';
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' || 'PENDING_REVIEW' || 'UPLOADED' => 'Pending review',
      'UNDER_REVIEW' => 'Under review',
      'VERIFIED' => 'Verified',
      'REJECTED' => 'Rejected',
      _ => status.replaceAll('_', ' '),
    };
  }

  Color _statusColor(String status, bool isDark) {
    return switch (status.toUpperCase()) {
      'VERIFIED' =>
        isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight,
      'REJECTED' =>
        isDark ? PMColors.statusDangerDark : PMColors.statusDangerLight,
      _ => isDark ? PMColors.statusWarningDark : PMColors.statusWarningLight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark
        ? PMColors.textPrimaryDark
        : PMColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark
        ? PMColors.bgSurfaceDark
        : PMColors.bgSurfaceLight;
    final borderColor = isDark
        ? PMColors.borderDefaultDark
        : PMColors.borderDefaultLight;
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Documents',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh documents',
            onPressed: _isUploading ? null : _loadDocuments,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Upload document',
            onPressed: _isUploading ? null : _selectAndUpload,
            icon: _isUploading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _DocumentMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Documents unavailable',
              message: _error!,
              actionLabel: 'Retry',
              actionIcon: Icons.refresh,
              onAction: _loadDocuments,
            )
          : _documents.isEmpty
          ? _DocumentMessage(
              icon: Icons.description_outlined,
              title: 'No documents yet',
              message: 'Your submitted documents will appear here.',
              actionLabel: 'Upload document',
              actionIcon: Icons.upload_file,
              onAction: _selectAndUpload,
            )
          : RefreshIndicator(
              onRefresh: _loadDocuments,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(PMSpacing.s4),
                itemCount: _documents.length,
                itemBuilder: (context, index) {
                  final document = _documents[index];
                  final statusColor = _statusColor(document.status, isDark);
                  final isOpening = _openingId == document.id;
                  final detailParts = <String>[
                    'Submitted ${_formatDate(document.createdAt)}',
                    'Version ${document.version}',
                    if (document.expiryDate != null)
                      'Expires ${_formatDate(document.expiryDate!)}',
                  ];

                  return Card(
                    margin: const EdgeInsets.only(bottom: PMSpacing.s3),
                    color: surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: PMRadius.sm,
                      side: BorderSide(color: borderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(PMSpacing.s4),
                      leading: Icon(
                        Icons.description_outlined,
                        color: isDark
                            ? PMColors.brandPrimaryDark
                            : PMColors.brandPrimaryLight,
                        size: 28,
                      ),
                      title: Text(
                        document.type,
                        style: PMTypography.headline.copyWith(color: textColor),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: PMSpacing.s2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PMSpacing.s2,
                                vertical: PMSpacing.s1,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: PMRadius.sm,
                              ),
                              child: Text(
                                _statusLabel(document.status),
                                style: PMTypography.caption.copyWith(
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: PMSpacing.s2),
                            Text(
                              detailParts.join('  |  '),
                              style: PMTypography.caption.copyWith(
                                color: secondaryTextColor,
                              ),
                            ),
                            if (document.rejectionReason?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: PMSpacing.s1,
                                ),
                                child: Text(
                                  'Reason: ${document.rejectionReason}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: PMTypography.caption.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: isOpening
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (document.status.toUpperCase() == 'REJECTED')
                                  IconButton(
                                    tooltip: 'Resubmit document',
                                    onPressed: _isUploading
                                        ? null
                                        : () => _selectAndUpload(
                                            resubmissionOf: document,
                                          ),
                                    icon: const Icon(Icons.refresh),
                                  ),
                                const Icon(Icons.open_in_new),
                              ],
                            ),
                      onTap: _openingId == null
                          ? () => _openDocument(document)
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _UploadMetadata {
  const _UploadMetadata(this.documentType, this.expiryDate);

  final String documentType;
  final DateTime? expiryDate;
}

class _DocumentMessage extends StatelessWidget {
  const _DocumentMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PMSpacing.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44, color: colorScheme.primary),
              const SizedBox(height: PMSpacing.s4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: PMTypography.headline,
              ),
              const SizedBox(height: PMSpacing.s2),
              Text(
                message,
                textAlign: TextAlign.center,
                style: PMTypography.body.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: PMSpacing.s5),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
