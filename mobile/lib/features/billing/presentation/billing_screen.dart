import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/billing_api.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final Razorpay _razorpay = Razorpay();
  BillingSummary? _summary;
  CheckoutOrder? _order;
  bool _isLoading = true;
  bool _isOpeningCheckout = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadSummary();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await ref.read(billingApiProvider).getSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _error = null;
        _isLoading = false;
      });
    } on TenantApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Billing is temporarily unavailable.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCheckout() async {
    if (_summary == null || _isOpeningCheckout) return;
    setState(() {
      _isOpeningCheckout = true;
      _notice = null;
      _error = null;
    });

    try {
      final order = await ref.read(billingApiProvider).createCheckoutOrder();
      if (!mounted) return;
      _order = order;
      _razorpay.open({
        'key': order.keyId,
        'amount': order.amountMinor,
        'currency': order.currency,
        'name': 'PayMuster',
        'description': 'Subscription renewal: ${order.planCode}',
        'order_id': order.orderId,
        'retry': {'enabled': true, 'max_count': 2},
        'timeout': 300,
      });
    } on TenantApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Unable to open the payment screen.');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final order = _order;
    if (order == null || response.orderId != order.orderId) {
      _showError('The payment order could not be matched to this checkout.');
      return;
    }
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      _showError('The payment confirmation was incomplete.');
      return;
    }

    try {
      final verification = await ref.read(billingApiProvider).verifyCheckout(
        orderId: order.orderId,
        paymentId: paymentId,
        signature: signature,
      );
      if (!mounted) return;
      setState(() {
        _isOpeningCheckout = false;
        _order = null;
        _notice = verification.awaitingWebhook
            ? 'Payment verified. Access will update after Razorpay confirms settlement.'
            : 'Payment confirmed and subscription access is active.';
        _error = null;
      });
      await _loadSummary();
    } on TenantApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Payment verification is temporarily unavailable.');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _isOpeningCheckout = false;
      _order = null;
      _error = 'Payment was not completed. Please try again.';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() {
      _isOpeningCheckout = false;
      _order = null;
      _notice = 'Payment handed off to ${response.walletName ?? 'the external wallet'}; awaiting confirmation.';
      _error = null;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isOpeningCheckout = false;
      _order = null;
      _error = message;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;
    final text = isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight;
    final secondary = isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text('Billing', style: PMTypography.title.copyWith(color: text)),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(PMSpacing.s6),
          children: [
            Text('Subscription payment', style: PMTypography.headline.copyWith(color: text)),
            const SizedBox(height: PMSpacing.s2),
            Text(
              'Payments are secured by Razorpay. Subscription access changes only after server confirmation.',
              style: PMTypography.body.copyWith(color: secondary),
            ),
            const SizedBox(height: PMSpacing.s6),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_summary != null) ...[
              _BillingDetails(summary: _summary!, textColor: text, secondaryColor: secondary),
              const SizedBox(height: PMSpacing.s6),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isOpeningCheckout ? null : _openCheckout,
                  icon: _isOpeningCheckout
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_outline),
                  label: Text(_isOpeningCheckout ? 'Opening payment' : 'Pay securely'),
                ),
              ),
            ],
            if (_error != null) ...[
              if (_summary != null) const SizedBox(height: PMSpacing.s4),
              _StatusPanel(message: _error!, color: PMColors.statusDangerDark, icon: Icons.error_outline),
            ],
            if (_notice != null) ...[
              const SizedBox(height: PMSpacing.s4),
              _StatusPanel(message: _notice!, color: PMColors.statusSuccessDark, icon: Icons.verified_outlined),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillingDetails extends StatelessWidget {
  const _BillingDetails({required this.summary, required this.textColor, required this.secondaryColor});

  final BillingSummary summary;
  final Color textColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final amount = (summary.plan.amountMinor / 100).toStringAsFixed(2);
    final periodEnd = DateFormat.yMMMd().format(summary.currentPeriodEnd.toLocal());
    return Container(
      padding: const EdgeInsets.all(PMSpacing.s6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
        borderRadius: BorderRadius.circular(PMSpacing.s3),
        border: Border.all(color: secondaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.plan.name, style: PMTypography.title.copyWith(color: textColor)),
          const SizedBox(height: PMSpacing.s1),
          Text(summary.plan.code, style: PMTypography.caption.copyWith(color: secondaryColor)),
          const SizedBox(height: PMSpacing.s4),
          Text('${summary.plan.currency} $amount', style: PMTypography.display.copyWith(color: textColor)),
          const SizedBox(height: PMSpacing.s2),
          Text('Billed ${summary.plan.interval.toLowerCase()}ly', style: PMTypography.body.copyWith(color: secondaryColor)),
          const SizedBox(height: PMSpacing.s4),
          Text('Status: ${summary.status}', style: PMTypography.body.copyWith(color: textColor)),
          Text('Current period ends $periodEnd', style: PMTypography.caption.copyWith(color: secondaryColor)),
          if (summary.unlimitedAccess)
            Padding(
              padding: const EdgeInsets.only(top: PMSpacing.s2),
              child: Text('Unlimited access enabled', style: PMTypography.body.copyWith(color: PMColors.statusSuccessDark)),
            ),
          if (summary.latestInvoice != null) ...[
            const SizedBox(height: PMSpacing.s4),
            Text(
              'Latest invoice: ${summary.latestInvoice!.invoiceNumber} (${summary.latestInvoice!.status})',
              style: PMTypography.caption.copyWith(color: secondaryColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.message, required this.color, required this.icon});

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PMSpacing.s4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(PMSpacing.s3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: PMSpacing.s3),
          Expanded(child: Text(message, style: PMTypography.body.copyWith(color: color))),
        ],
      ),
    );
  }
}
