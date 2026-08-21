import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/admin_tokens.dart';
import '../data/admin_api_client.dart';
import 'widgets/admin_ui_helpers.dart';

class AdminDocumentsScreen extends ConsumerStatefulWidget {
  const AdminDocumentsScreen({super.key});

  @override
  ConsumerState<AdminDocumentsScreen> createState() =>
      _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends ConsumerState<AdminDocumentsScreen> {
  List<Map<String, dynamic>> _documents = const [];
  bool _isLoading = true;
  String? _error;
  String? _processingId;
  String? _viewingId;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final documents = await ref
          .read(adminApiClientProvider)
          .getPendingDocuments();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _viewDocument(Map<String, dynamic> document) async {
    final documentId = document['id'] as String?;
    if (documentId == null || documentId.isEmpty) {
      _showError('This document has no valid database ID.');
      return;
    }
    if (_viewingId != null) return;

    setState(() => _viewingId = documentId);
    try {
      final uri = await ref
          .read(adminApiClientProvider)
          .createDocumentViewUrl(documentId);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw Exception('The document could not be opened on this device.');
      }
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _viewingId = null);
    }
  }

  Future<void> _verifyDocument(Map<String, dynamic> document) async {
    final documentId = document['id'] as String?;
    if (documentId == null || documentId.isEmpty) {
      _showError('This document has no valid database ID.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify document?'),
        content: const Text(
          'Confirm that this document has been reviewed and is valid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Verify'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runMutation(
      documentId,
      () => ref.read(adminApiClientProvider).verifyDocument(documentId),
      'Document verified',
    );
  }

  Future<void> _rejectDocument(Map<String, dynamic> document) async {
    final documentId = document['id'] as String?;
    if (documentId == null || documentId.isEmpty) {
      _showError('This document has no valid database ID.');
      return;
    }

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject document?'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Rejection reason',
            hintText: 'Enter the reason shown in the audit record',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: AdminColors.onError,
            ),
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    await _runMutation(
      documentId,
      () => ref.read(adminApiClientProvider).rejectDocument(documentId, reason),
      'Document rejected',
    );
  }

  Future<void> _runMutation(
    String documentId,
    Future<Map<String, dynamic>> Function() mutation,
    String successMessage,
  ) async {
    if (_processingId != null) return;
    setState(() => _processingId = documentId);
    try {
      await mutation();
      if (!mounted) return;
      await _loadDocuments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AdminColors.success,
        ),
      );
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AdminColors.danger),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception: '), '');
  }

  String _statusLabel(dynamic status) {
    final value = status as String? ?? 'PENDING_REVIEW';
    return switch (value.toUpperCase()) {
      'PENDING' || 'PENDING_REVIEW' || 'UPLOADED' => 'PENDING',
      'UNDER_REVIEW' => 'IN REVIEW',
      _ => value.replaceAll('_', ' '),
    };
  }

  String _displayName(Map<String, dynamic> document) {
    final staff = document['staff'] as Map<String, dynamic>? ?? const {};
    final parts = [
      staff['firstName'],
      staff['lastName'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    return staff['email'] as String? ?? 'Name unavailable';
  }

  String _dateValue(dynamic value) {
    final text = value as String?;
    if (text == null || text.isEmpty) return 'Unavailable';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AdminColors.onSurface;
    final surfaceColor = AdminColors.surfaceContainer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Documents'),
        actions: [
          IconButton(
            tooltip: 'Refresh documents',
            onPressed: _processingId == null ? _loadDocuments : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const AdminLoadingState()
          : _error != null
          ? AdminErrorState(error: _error!, onRetry: _loadDocuments)
          : _documents.isEmpty
          ? const AdminEmptyState(
              icon: Icons.task_alt,
              title: 'No Pending Documents',
              message: 'There are no documents awaiting review.',
            )
          : RefreshIndicator(
              onRefresh: _loadDocuments,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AdminSpacing.md),
                itemCount: _documents.length,
                itemBuilder: (context, index) {
                  final document = _documents[index];
                  final org =
                      document['org'] as Map<String, dynamic>? ?? const {};
                  final documentId = document['id'] as String? ?? '';
                  final isProcessing = _processingId == documentId;
                  final isViewing = _viewingId == documentId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
                    color: surfaceColor,
                    child: Padding(
                      padding: const EdgeInsets.all(AdminSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  document['type'] as String? ??
                                      'Type unavailable',
                                  style: AdminTypography.titleMd.copyWith(
                                    color: textColor,
                                  ),
                                ),
                              ),
                              AdminBadge(
                                label: _statusLabel(document['status']),
                                color: AdminColors.warning,
                                icon: Icons.schedule_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: AdminSpacing.sm),
                          Text(
                            _displayName(document),
                            style: AdminTypography.titleSm.copyWith(
                              color: textColor,
                            ),
                          ),
                          Text(
                            org['name'] as String? ??
                                'Organization unavailable',
                            style: AdminTypography.bodySm.copyWith(
                              color: AdminColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AdminSpacing.compact),
                          Text(
                            'Version ${(document['version'] as num?)?.toInt() ?? 1}  '
                            'Submitted: ${_dateValue(document['createdAt'])}  '
                            'Expiry: ${_dateValue(document['expiryDate'])}',
                            style: AdminTypography.bodySm.copyWith(
                              color: AdminColors.onSurfaceVariant,
                            ),
                          ),
                          if ((document['rejectionReason'] as String?)
                                  ?.isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AdminSpacing.xs,
                              ),
                              child: Text(
                                'Rejection reason: ${document['rejectionReason']}',
                                style: AdminTypography.bodySm.copyWith(
                                  color: AdminColors.danger,
                                ),
                              ),
                            ),
                          if (document['reviewerId'] != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AdminSpacing.xs,
                              ),
                              child: Text(
                                'Reviewer: ${document['reviewerId']}',
                                style: AdminTypography.bodySm.copyWith(
                                  color: AdminColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          const SizedBox(height: AdminSpacing.compact),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _viewingId == null && _processingId == null
                                  ? () => _viewDocument(document)
                                  : null,
                              icon: isViewing
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.open_in_new),
                              label: Text(
                                isViewing ? 'Opening...' : 'View document',
                              ),
                            ),
                          ),
                          const SizedBox(height: AdminSpacing.md),
                          if (isProcessing)
                            const LinearProgressIndicator()
                          else
                            Row(
                              children: [
                                if ((document['status'] as String? ?? '') !=
                                    'UNDER_REVIEW')
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _processingId == null &&
                                              _viewingId == null
                                          ? () => _runMutation(
                                              documentId,
                                              () => ref
                                                  .read(adminApiClientProvider)
                                                  .claimDocument(documentId),
                                              'Document moved to review',
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.rate_review_outlined,
                                      ),
                                      label: const Text('Start review'),
                                    ),
                                  ),
                                if ((document['status'] as String? ?? '') !=
                                    'UNDER_REVIEW')
                                  const SizedBox(width: AdminSpacing.sm),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed:
                                        _processingId == null &&
                                            _viewingId == null
                                        ? () => _verifyDocument(document)
                                        : null,
                                    icon: const Icon(Icons.verified_outlined),
                                    label: const Text('Verify'),
                                  ),
                                ),
                                const SizedBox(width: AdminSpacing.sm),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _processingId == null &&
                                            _viewingId == null
                                        ? () => _rejectDocument(document)
                                        : null,
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AdminColors.danger,
                                      side: const BorderSide(
                                        color: AdminColors.danger,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
