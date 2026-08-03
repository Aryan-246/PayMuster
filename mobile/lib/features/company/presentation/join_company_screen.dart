import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/company_provider.dart';

import '../../auth/presentation/auth_controller.dart';

class JoinCompanyScreen extends ConsumerStatefulWidget {
  const JoinCompanyScreen({super.key});

  @override
  ConsumerState<JoinCompanyScreen> createState() => _JoinCompanyScreenState();
}

class _JoinCompanyScreenState extends ConsumerState<JoinCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitJoinRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final api = ref.read(companyProvider);
      final company = await api.lookupCompany(_codeController.text.trim());
      
      await api.joinCompany(company['id']);
      
      if (!mounted) return;
      
      ref.read(authControllerProvider.notifier).fetchMe();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Join request submitted to ${company['name']}! Waiting for owner approval.'),
          backgroundColor: PMColors.statusSuccessDark,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $e'),
          backgroundColor: PMColors.statusDangerDark,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Company'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(PMSpacing.s8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the Company Reference Code or Join Code provided by your employer to send a join request.',
                style: PMTypography.body,
              ),
              const SizedBox(height: PMSpacing.s10),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Company Code',
                  hintText: 'e.g. COMP-12345',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a valid code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PMSpacing.s12),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitJoinRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
