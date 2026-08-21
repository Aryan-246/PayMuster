import 'package:flutter/material.dart';
import '../theme/admin_tokens.dart';

class AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AdminRadius.xl,
        child: Container(
          padding: const EdgeInsets.all(AdminSpacing.md),
          decoration: BoxDecoration(
            color: AdminColors.surfaceContainer,
            borderRadius: AdminRadius.xl,
            border: Border.all(color: AdminColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AdminSpacing.sm),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AdminRadius.md,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AdminColors.onSurfaceMuted,
                    ),
                ],
              ),
              const SizedBox(height: AdminSpacing.md),
              Text(
                value,
                style: AdminTypography.statValue.copyWith(
                  color: AdminColors.onSurface,
                ),
              ),
              const SizedBox(height: AdminSpacing.xs),
              Text(
                title,
                style: AdminTypography.bodySm.copyWith(
                  color: AdminColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AdminBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory AdminBadge.role(String role) {
    final r = role.toUpperCase();
    return switch (r) {
      'SUPER_ADMIN' || 'SUPERADMIN' => const AdminBadge(
        label: 'Super Admin',
        color: AdminColors.primary,
        icon: Icons.admin_panel_settings_outlined,
      ),
      'OWNER' => const AdminBadge(
        label: 'Owner',
        color: AdminColors.info,
        icon: Icons.business_outlined,
      ),
      'ADMIN' => const AdminBadge(
        label: 'Admin',
        color: AdminColors.secondary,
        icon: Icons.shield_outlined,
      ),
      'SUPERVISOR' => const AdminBadge(
        label: 'Supervisor',
        color: AdminColors.warning,
        icon: Icons.supervisor_account_outlined,
      ),
      'ACCOUNTANT' => const AdminBadge(
        label: 'Accountant',
        color: AdminColors.success,
        icon: Icons.calculate_outlined,
      ),
      'VIEWER' => const AdminBadge(
        label: 'Viewer',
        color: AdminColors.neutral,
        icon: Icons.visibility_outlined,
      ),
      _ => const AdminBadge(
        label: 'Staff',
        color: AdminColors.neutral,
        icon: Icons.person_outline,
      ),
    };
  }

  factory AdminBadge.status(String status, {bool isDisabled = false}) {
    final normalized = status.toUpperCase();
    if (isDisabled ||
        normalized == 'BLOCKED' ||
        normalized == 'SUSPENDED' ||
        normalized == 'DELETED' ||
        normalized == 'REJECTED') {
      return AdminBadge(
        label: isDisabled ? 'Blocked' : normalized,
        color: AdminColors.danger,
        icon: Icons.block_outlined,
      );
    }
    if (normalized == 'ACTIVE' ||
        normalized == 'APPROVED' ||
        normalized == 'VERIFIED' ||
        normalized == 'PRESENT') {
      return AdminBadge(
        label: normalized,
        color: AdminColors.success,
        icon: Icons.check_circle_outline,
      );
    }
    if (normalized == 'PENDING' || normalized == 'CALCULATED') {
      return AdminBadge(
        label: normalized,
        color: AdminColors.warning,
        icon: Icons.schedule_outlined,
      );
    }
    return AdminBadge(
      label: status,
      color: AdminColors.neutral,
      icon: Icons.info_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AdminRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AdminTypography.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AdminTypography.headlineSm.copyWith(
            color: AdminColors.onSurface,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: AdminTypography.titleSm.copyWith(
                color: AdminColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: AdminColors.primary.withValues(alpha: 0.65),
            ),
            const SizedBox(height: AdminSpacing.md),
            Text(
              title,
              style: AdminTypography.headlineSm.copyWith(
                color: AdminColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              message,
              style: AdminTypography.bodyMd.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AdminSpacing.lg),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: AdminColors.onPrimary,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AdminSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class AdminErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const AdminErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AdminColors.danger,
            ),
            const SizedBox(height: AdminSpacing.md),
            Text(
              'Failed to load data',
              style: AdminTypography.headlineSm.copyWith(
                color: AdminColors.onSurface,
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),
            Text(
              error,
              style: AdminTypography.bodyMd.copyWith(
                color: AdminColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdminSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: AdminColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
