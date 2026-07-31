import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/layout/pm_card.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../domain/worker.dart';
import '../data/worker_repository.dart';

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(workersListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            _buildSearchBar(isDark),
            Expanded(
              child: workersAsync.when(
                data: (workers) => _buildWorkerList(workers, isDark),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
        child: Icon(
          Icons.add,
          color: isDark ? PMColors.brandOnPrimaryDark : PMColors.brandOnPrimaryLight,
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PMSpacing.s5, PMSpacing.s4, PMSpacing.s5, PMSpacing.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Workers', style: PMTypography.title),
          Icon(
            Icons.filter_list,
            color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
      child: const PMTextInput(
        hintText: 'Search by name, ID or role',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildWorkerList(List<Worker> workers, bool isDark) {
    if (workers.isEmpty) {
      return Center(
        child: Text(
          'No workers found.',
          style: PMTypography.body.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s4),
      itemCount: workers.length,
      separatorBuilder: (context, index) => const SizedBox(height: PMSpacing.s3),
      itemBuilder: (context, index) {
        final worker = workers[index];
        return GestureDetector(
          onTap: () => context.push('/app/sites/${worker.id}'),
          child: PMCard.standard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? PMColors.bgSunkenDark : PMColors.bgSunkenLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    worker.firstName.substring(0, 1) + worker.lastName.substring(0, 1),
                    style: PMTypography.labelLarge.copyWith(
                      color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PMSpacing.s4),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.fullName, style: PMTypography.headline),
                    const SizedBox(height: PMSpacing.s1),
                    Text(
                      '${worker.role} • ID: ${worker.employeeId}',
                      style: PMTypography.caption.copyWith(
                        color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s2, vertical: 4),
                decoration: BoxDecoration(
                  color: worker.status == 'Active'
                      ? (isDark ? PMColors.statusSuccessContainerDark : PMColors.statusSuccessContainerLight)
                      : (isDark ? PMColors.bgSunkenDark : PMColors.bgSunkenLight),
                  borderRadius: PMRadius.sm,
                ),
                child: Text(
                  worker.status,
                  style: PMTypography.caption.copyWith(
                    color: worker.status == 'Active'
                        ? (isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight)
                        : (isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}
