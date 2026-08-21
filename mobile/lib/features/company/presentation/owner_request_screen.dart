import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../../../components/foundation/pm_button.dart';
import '../../company/data/company_provider.dart';

class OwnerRequestScreen extends ConsumerStatefulWidget {
  const OwnerRequestScreen({super.key});

  @override
  ConsumerState<OwnerRequestScreen> createState() => _OwnerRequestScreenState();
}

class _OwnerRequestScreenState extends ConsumerState<OwnerRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _gstinController = TextEditingController();
  final _businessRegistrationUrlController = TextEditingController();
  final _identityProofUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _gstinController.dispose();
    _businessRegistrationUrlController.dispose();
    _identityProofUrlController.dispose();
    super.dispose();
  }

  String? _validateCompanyName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 2) return 'Enter at least 2 characters';
    if (trimmed.length > 120) return 'Use 120 characters or fewer';
    return null;
  }

  String? _validateOptionalText(String? value, int maximum) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.length > maximum) {
      return 'Use $maximum characters or fewer';
    }
    return null;
  }

  String? _validateOptionalHttpsUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 2048) return 'Use 2048 characters or fewer';
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      return 'Enter a valid HTTPS URL';
    }
    return null;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(companyProvider);
      await api.requestOwnership(
        _companyNameController.text,
        companyAddress: _companyAddressController.text,
        gstin: _gstinController.text,
        businessRegistrationUrl: _businessRegistrationUrlController.text,
        identityProofUrl: _identityProofUrlController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Owner request submitted successfully.'),
          backgroundColor: PMColors.statusSuccessDark,
        ),
      );
      context.go('/app/promotion-status');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark
        ? PMColors.bgSurfaceDark
        : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Become an Owner',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PMSpacing.s6),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submit a request to become an owner of a new company. Our team will review your application.',
                style: PMTypography.body.copyWith(color: textColor),
              ),
              const SizedBox(height: PMSpacing.s8),
              PMTextInput(
                key: const Key('owner-company-name'),
                labelText: 'Company Name',
                controller: _companyNameController,
                enabled: !_isLoading,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                validator: _validateCompanyName,
              ),
              const SizedBox(height: PMSpacing.s4),
              PMTextInput(
                key: const Key('owner-company-address'),
                labelText: 'Company Address (Optional)',
                controller: _companyAddressController,
                enabled: !_isLoading,
                maxLines: 3,
                maxLength: 500,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                validator: (value) => _validateOptionalText(value, 500),
              ),
              const SizedBox(height: PMSpacing.s4),
              PMTextInput(
                key: const Key('owner-gstin'),
                labelText: 'GSTIN (Optional)',
                controller: _gstinController,
                enabled: !_isLoading,
                maxLength: 20,
                textInputAction: TextInputAction.next,
                validator: (value) => _validateOptionalText(value, 20),
              ),
              const SizedBox(height: PMSpacing.s4),
              PMTextInput(
                key: const Key('owner-business-registration-url'),
                labelText: 'Business Registration URL (Optional)',
                hintText: 'https://example.com/registration',
                controller: _businessRegistrationUrlController,
                enabled: !_isLoading,
                maxLength: 2048,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: _validateOptionalHttpsUrl,
              ),
              const SizedBox(height: PMSpacing.s4),
              PMTextInput(
                key: const Key('owner-identity-proof-url'),
                labelText: 'Identity Proof URL (Optional)',
                hintText: 'https://example.com/identity-proof',
                controller: _identityProofUrlController,
                enabled: !_isLoading,
                maxLength: 2048,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                validator: _validateOptionalHttpsUrl,
              ),
              const SizedBox(height: PMSpacing.s8),
              PMButton.primary(
                key: const Key('owner-submit-request'),
                label: _isLoading ? 'Submitting…' : 'Submit Request',
                onPressed: _isLoading ? null : _submitRequest,
                icon: Icons.send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
