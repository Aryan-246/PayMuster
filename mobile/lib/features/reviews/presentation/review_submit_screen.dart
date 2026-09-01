import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/reviews_api.dart';

/// "Rate your company" (§ latest directive #5, member side): star rating +
/// free text, submitted to POST /api/v1/reviews. Shows the user's existing
/// review with its honest moderation state — a duplicate submission surfaces
/// the server's REVIEW_DUPLICATE conflict, never a fake success.
class ReviewSubmitScreen extends ConsumerStatefulWidget {
  const ReviewSubmitScreen({super.key});

  @override
  ConsumerState<ReviewSubmitScreen> createState() =>
      _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends ConsumerState<ReviewSubmitScreen> {
  List<MyReview> _mine = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  int _rating = 0;
  final _textController = TextEditingController();
  String? _validationError;

  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoading = _mine.isEmpty;
      _error = null;
    });

    try {
      final mine = await ref.read(reviewsApiProvider).listMine();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _mine = mine;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (_rating < 1) {
      setState(() => _validationError = 'Choose a star rating first.');
      return;
    }
    if (text.length < 5) {
      setState(
          () => _validationError = 'Please write at least 5 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    try {
      await ref.read(reviewsApiProvider).submit(rating: _rating, text: text);
      if (!mounted) return;
      setState(() {
        _textController.clear();
        _rating = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Review submitted. It will be visible once a moderator publishes it.'),
        ),
      );
      await _load();
    } on TenantApiException catch (e) {
      if (!mounted) return;
      setState(() => _validationError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _validationError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final textColor =
        isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondaryColor =
        isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;
    final brand = isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight;

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          color: isDark
                              ? PMColors.statusDangerDark
                              : PMColors.statusDangerLight,
                          size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondaryColor),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildComposer(context, surface, textColor, secondaryColor,
                        brand, isDark),
                    const SizedBox(height: 16),
                    ..._mine.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildExistingReview(
                            r, surface, textColor, secondaryColor, isDark),
                      ),
                    ),
                  ],
                ),
              );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Rate Your Company'),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: body,
    );
  }

  Widget _buildComposer(
    BuildContext context,
    Color surface,
    Color textColor,
    Color secondaryColor,
    Color brand,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share your experience',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Your review goes to PayMuster platform moderators first. It '
            'becomes public only after it is published.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: secondaryColor),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                iconSize: 36,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                icon: Icon(
                  star <= _rating ? Icons.star : Icons.star_border,
                  color: star <= _rating ? brand : secondaryColor,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() {
                          _rating = star;
                          _validationError = null;
                        }),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            enabled: !_isSubmitting,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText:
                  'What is working well? What could be better? (5–2000 characters)',
              border: const OutlineInputBorder(),
              counterText: '',
              errorText: _validationError,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: brand,
                foregroundColor:
                    isDark ? PMColors.brandOnPrimaryDark : PMColors.brandOnPrimaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(_isSubmitting ? 'Submitting…' : 'Submit review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingReview(
    MyReview r,
    Color surface,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final statusColor = switch (r.status) {
      'PUBLISHED' =>
        isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight,
      'FLAGGED' =>
        isDark ? PMColors.statusDangerDark : PMColors.statusDangerLight,
      'PENDING' =>
        isDark ? PMColors.statusWarningDark : PMColors.statusWarningLight,
      _ => secondaryColor,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < r.rating ? Icons.star : Icons.star_border,
                    color: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  r.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r.text,
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${r.publicId ?? ''} • submitted ${_fmt(r.createdAt)}'
            '${r.status == 'PENDING' ? ' • awaiting moderation' : ''}',
            style: TextStyle(color: secondaryColor, fontSize: 12),
          ),
          if (r.adminResponse != null && r.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark
                        ? PMColors.brandPrimaryDark
                        : PMColors.brandPrimaryLight)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response from PayMuster',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.adminResponse!,
                    style: TextStyle(color: textColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _fmt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
