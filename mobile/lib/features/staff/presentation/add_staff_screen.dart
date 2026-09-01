import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/foundation/pm_button.dart';
import '../../../core/network/tenant_api_client.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/staff_directory_api.dart';
import 'staff_directory_controller.dart';

/// Manual worker add (owner.txt staff section) — POST /api/v1/staff under
/// manage_staff. Client-side validation mirrors the server schema; the server
/// remains authoritative (duplicate phone → 409, invalid IFSC → 400).
class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();

  String _workerType = 'DAILY';
  String? _preferredPaymentMethod;
  bool _submitting = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _bankAccount.dispose();
    _ifsc.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);

    final input = CreateStaffInput(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      workerType: _workerType,
      bankAccountNumber: _bankAccount.text.trim().isEmpty
          ? null
          : _bankAccount.text.trim(),
      ifscCode: _ifsc.text.trim().isEmpty ? null : _ifsc.text.trim().toUpperCase(),
      upiId: _upi.text.trim().isEmpty ? null : _upi.text.trim(),
      preferredPaymentMethod: _preferredPaymentMethod,
    );

    try {
      final member = await ref
          .read(staffDirectoryApiProvider)
          .createStaff(input);
      ref.read(staffDirectoryControllerProvider.notifier).reloadAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.fullName} added (${member.publicId})')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is TenantApiException
                ? error.message
                : 'The worker could not be added.',
          ),
        ),
      );
      setState(() => _submitting = false);
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
    final secondary = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Add Worker',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PMSpacing.s5),
          children: [
            Text(
              'Add a worker to your company. They appear on the roster immediately; '
              'payment verification completes once bank/UPI details exist and a '
              'document is approved.',
              style: PMTypography.body.copyWith(color: secondary),
            ),
            const SizedBox(height: PMSpacing.s5),
            _Field(
              controller: _firstName,
              label: 'First name',
              keyId: 'add-staff-first-name',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'First name is required'
                  : null,
            ),
            _Field(
              controller: _lastName,
              label: 'Last name',
              keyId: 'add-staff-last-name',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Last name is required'
                  : null,
            ),
            _Field(
              controller: _phone,
              label: 'Phone number',
              keyId: 'add-staff-phone',
              keyboardType: TextInputType.phone,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Phone number is required';
                if (text.length < 6 || text.length > 20) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            _Field(
              controller: _email,
              label: 'Email (optional)',
              keyId: 'add-staff-email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                if (!RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                ).hasMatch(text)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: PMSpacing.s4),
            Text('Worker type', style: PMTypography.body.copyWith(color: textColor)),
            const SizedBox(height: PMSpacing.s2),
            SegmentedButton<String>(
              key: const Key('add-staff-worker-type'),
              segments: const [
                ButtonSegment(value: 'DAILY', label: Text('Daily')),
                ButtonSegment(value: 'MONTHLY', label: Text('Monthly')),
                ButtonSegment(value: 'CONTRACT', label: Text('Contract')),
              ],
              selected: {_workerType},
              onSelectionChanged: (selection) =>
                  setState(() => _workerType = selection.first),
            ),
            const SizedBox(height: PMSpacing.s5),
            Text(
              'Payment details (optional — can be completed later)',
              style: PMTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: PMSpacing.s2),
            _Field(
              controller: _bankAccount,
              label: 'Bank account number',
              keyId: 'add-staff-bank',
              keyboardType: TextInputType.number,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                if (text.length < 4 || text.length > 34) {
                  return 'Bank account must be 4–34 digits';
                }
                return null;
              },
            ),
            _Field(
              controller: _ifsc,
              label: 'IFSC code',
              keyId: 'add-staff-ifsc',
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                final text = value?.trim().toUpperCase() ?? '';
                if (text.isEmpty) return null;
                if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(text)) {
                  return 'IFSC format: 4 letters, 0, 6 alphanumerics';
                }
                return null;
              },
            ),
            _Field(
              controller: _upi,
              label: 'UPI ID',
              keyId: 'add-staff-upi',
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                if (text.length < 3) return 'UPI ID looks too short';
                return null;
              },
            ),
            const SizedBox(height: PMSpacing.s4),
            DropdownButtonFormField<String?>(
              key: const Key('add-staff-preferred-method'),
              initialValue: _preferredPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'Preferred payment method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Not set')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(value: 'BANK', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              ],
              onChanged: (value) =>
                  setState(() => _preferredPaymentMethod = value),
            ),
            const SizedBox(height: PMSpacing.s6),
            PMButton.primary(
              key: const Key('add-staff-submit'),
              label: 'Add worker',
              icon: Icons.person_add_alt,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: PMSpacing.s8),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.keyId,
    this.validator,
    this.keyboardType,
    this.textCapitalization,
  });

  final TextEditingController controller;
  final String label;
  final String keyId;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization? textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PMSpacing.s4),
      child: TextFormField(
        key: Key(keyId),
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization:
            textCapitalization ?? TextCapitalization.none,
        autofillHints: keyboardType == TextInputType.phone
            ? const [AutofillHints.telephoneNumber]
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
