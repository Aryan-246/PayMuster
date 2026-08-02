import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/layout/pm_card.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../../../components/feedback/pm_list_skeleton.dart';
import '../domain/payroll_record.dart';
import '../data/payroll_repository.dart';

class PayrollSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void updateQuery(String query) => state = query;
}

final payrollSearchProvider = NotifierProvider<PayrollSearchNotifier, String>(() => PayrollSearchNotifier());

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recordsAsync = ref.watch(payrollListProvider('Jun 2024'));
    final searchQuery = ref.watch(payrollSearchProvider).toLowerCase();

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            _buildSummaryCard(isDark),
            _buildSearchBar(isDark, ref),
            Expanded(
              child: recordsAsync.when(
                data: (records) {
                  final filtered = records.where((r) {
                    return r.workerName.toLowerCase().contains(searchQuery) ||
                           r.role.toLowerCase().contains(searchQuery);
                  }).toList();
                  
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('No workers found.', style: PMTypography.body.copyWith(color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight)),
                    );
                  }
                  return _buildPayrollList(filtered, isDark);
                },
                loading: () => const PMListSkeleton(),
                error: (error, stack) => Center(child: Text('Error loading payroll.', style: PMTypography.body.copyWith(color: PMColors.statusDangerDark))),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
        icon: Icon(
          Icons.payments,
          color: isDark ? PMColors.brandOnPrimaryDark : PMColors.brandOnPrimaryLight,
        ),
        label: Text(
          'Process Run',
          style: PMTypography.labelLarge.copyWith(
            color: isDark ? PMColors.brandOnPrimaryDark : PMColors.brandOnPrimaryLight,
          ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payroll Run', style: PMTypography.title),
              const SizedBox(height: PMSpacing.s1),
              Row(
                children: [
                  Text(
                    'Jun 2024',
                    style: PMTypography.body.copyWith(
                      color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ],
              ),
            ],
          ),
          Icon(
            Icons.filter_list,
            color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
      child: PMCard.standard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Payroll',
              style: PMTypography.caption.copyWith(
                color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: PMSpacing.s1),
            Text('₹14,25,000', style: PMTypography.display),
            const SizedBox(height: PMSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workers',
                        style: PMTypography.caption.copyWith(
                          color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: PMSpacing.s1),
                      Text('284', style: PMTypography.headline),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disbursed',
                        style: PMTypography.caption.copyWith(
                          color: PMColors.statusSuccessDark,
                        ),
                      ),
                      const SizedBox(height: PMSpacing.s1),
                      Text('₹8,50,000', style: PMTypography.headline),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
      child: PMTextInput(
        hintText: 'Search worker',
        prefixIcon: const Icon(Icons.search),
        onChanged: (val) => ref.read(payrollSearchProvider.notifier).updateQuery(val),
      ),
    );
  }

  Widget _buildPayrollList(List<PayrollRecord> records, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s4),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: PMSpacing.s3),
      itemBuilder: (context, index) {
        final record = records[index];
        final isPaid = record.status == 'Paid';

        return PMCard.standard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.workerName, style: PMTypography.headline),
                    const SizedBox(height: PMSpacing.s1),
                    Text(
                      '${record.role} • ${record.daysWorked} Days',
                      style: PMTypography.caption.copyWith(
                        color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${record.amount.toStringAsFixed(0)}',
                    style: PMTypography.labelLarge,
                  ),
                  const SizedBox(height: PMSpacing.s1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? (isDark ? PMColors.statusSuccessContainerDark : PMColors.statusSuccessContainerLight)
                          : (isDark ? PMColors.statusWarningContainerDark : PMColors.statusWarningContainerLight),
                      borderRadius: PMRadius.sm,
                    ),
                    child: Text(
                      record.status.toUpperCase(),
                      style: PMTypography.overline.copyWith(
                        color: isPaid
                            ? (isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight)
                            : (isDark ? PMColors.statusWarningDark : PMColors.statusWarningLight),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
