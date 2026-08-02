import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_button.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  UserRole? _selectedRole;

  void _completeProfile() {
    if (_selectedRole != null) {
      // In a real app, this would update the user profile on the backend
      context.go('/app/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final cardColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Complete Profile', style: PMTypography.title.copyWith(color: textColor)),
        automaticallyImplyLeading: false, // Force them to complete this step
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What is your role?',
                style: PMTypography.display.copyWith(color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us customize your experience.',
                style: PMTypography.bodyLarge.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: UserRole.values.map((role) {
                    final isSelected = _selectedRole == role;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRole = role;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? PMColors.brandPrimaryDark : (isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getIconForRole(role),
                              color: isSelected ? PMColors.brandPrimaryDark : textColor,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatRoleName(role),
                                    style: PMTypography.headline.copyWith(
                                      color: isSelected ? PMColors.brandPrimaryDark : textColor,
                                    ),
                                  ),
                                  Text(
                                    _getDescriptionForRole(role),
                                    style: PMTypography.caption.copyWith(
                                      color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: PMColors.brandPrimaryDark),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              PMButton.primary(
                label: 'Continue',
                onPressed: _selectedRole != null ? _completeProfile : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRoleName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin: return 'Super Admin';
      case UserRole.companyOwner: return 'Company Owner';
      case UserRole.siteManager: return 'Site Manager';
      case UserRole.supervisor: return 'Supervisor';
      case UserRole.worker: return 'Worker';
    }
  }

  String _getDescriptionForRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin: return 'Full system access';
      case UserRole.companyOwner: return 'Manages entire company';
      case UserRole.siteManager: return 'Manages multiple sites';
      case UserRole.supervisor: return 'Manages workers on a site';
      case UserRole.worker: return 'Field worker';
    }
  }

  IconData _getIconForRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin: return Icons.admin_panel_settings;
      case UserRole.companyOwner: return Icons.business;
      case UserRole.siteManager: return Icons.domain;
      case UserRole.supervisor: return Icons.assignment_ind;
      case UserRole.worker: return Icons.engineering;
    }
  }
}
