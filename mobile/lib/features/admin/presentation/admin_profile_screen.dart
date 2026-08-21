import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'theme/admin_tokens.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminSpacing.gutterMobile),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: user == null
                ? const _UnavailableIdentity()
                : _IdentityContent(user: user),
          ),
        ),
      ),
    );
  }
}

class _IdentityContent extends StatelessWidget {
  final User user;

  const _IdentityContent({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user.name?.trim();
    final publicId = user.publicId?.trim();
    final organizationId = user.organizationId?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AdminSpacing.lg),
          decoration: BoxDecoration(
            color: AdminColors.surfaceContainerLow,
            borderRadius: AdminRadius.lg,
            border: Border.all(color: AdminColors.glassBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AdminColors.secondaryContainer,
                child: Text(
                  _initials(displayName, user.email),
                  style: AdminTypography.titleMd.copyWith(
                    color: AdminColors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName?.isNotEmpty == true
                          ? displayName!
                          : 'Name not provided',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTypography.titleMd.copyWith(
                        color: AdminColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.xs),
                    Text(
                      user.email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTypography.bodyMd.copyWith(
                        color: AdminColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminSpacing.sm,
                        vertical: AdminSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.primaryContainer.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: AdminRadius.base,
                      ),
                      child: Text(
                        _roleLabel(user.role),
                        style: AdminTypography.labelSm.copyWith(
                          color: AdminColors.primaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AdminSpacing.lg),
        Text(
          'Authenticated Identity',
          style: AdminTypography.titleMd.copyWith(color: AdminColors.onSurface),
        ),
        const SizedBox(height: AdminSpacing.sm),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AdminColors.surfaceContainerLow,
            borderRadius: AdminRadius.lg,
            border: Border.all(color: AdminColors.glassBorder),
          ),
          child: Column(
            children: [
              _IdentityRow(label: 'Email', value: user.email),
              const Divider(height: 1, color: AdminColors.glassBorder),
              _IdentityRow(label: 'Role', value: _roleLabel(user.role)),
              const Divider(height: 1, color: AdminColors.glassBorder),
              _IdentityRow(label: 'User ID', value: user.id),
              if (publicId?.isNotEmpty == true) ...[
                const Divider(height: 1, color: AdminColors.glassBorder),
                _IdentityRow(label: 'Public ID', value: publicId!),
              ],
              if (organizationId?.isNotEmpty == true) ...[
                const Divider(height: 1, color: AdminColors.glassBorder),
                _IdentityRow(label: 'Organization ID', value: organizationId!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String? name, String email) {
    final source = name?.isNotEmpty == true ? name! : email;
    final parts = source.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return source.trim().isNotEmpty ? source.trim()[0].toUpperCase() : 'SA';
  }

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.superAdmin => 'Super Admin',
    UserRole.owner => 'Owner',
    UserRole.admin => 'Admin',
    UserRole.supervisor => 'Supervisor',
    UserRole.accountant => 'Accountant',
    UserRole.staff => 'Staff',
    UserRole.viewer => 'Viewer',
  };
}

class _IdentityRow extends StatelessWidget {
  final String label;
  final String value;

  const _IdentityRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AdminTypography.bodyMd.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: SelectableText(
              value,
              style: AdminTypography.bodyMd.copyWith(
                color: AdminColors.onSurface,
                fontFamily: AdminTypography.monoFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableIdentity extends StatelessWidget {
  const _UnavailableIdentity();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surfaceContainerLow,
        borderRadius: AdminRadius.lg,
        border: Border.all(color: AdminColors.glassBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 32,
            color: AdminColors.onSurfaceVariant,
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            'Authenticated identity is unavailable.',
            textAlign: TextAlign.center,
            style: AdminTypography.bodyMd.copyWith(
              color: AdminColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
