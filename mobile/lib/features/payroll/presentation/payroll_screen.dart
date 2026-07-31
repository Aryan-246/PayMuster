import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/layout/pm_card.dart';
import '../../../components/foundation/pm_text_input.dart';

class PayrollRecord {
  final String workerName;
  final String role;
  final int daysWorked;
  final double amount;
  final String status; // Pending, Paid

  const PayrollRecord({
    required this.workerName,
    required this.role,
    required this.daysWorked,
    required this.amount,
    required this.status,
  });
}

final payrollListProvider = Provider<List<PayrollRecord>>((ref) {
  return [
    const PayrollRecord(workerName: 'Ramesh Kumar', role: 'Electrician', daysWorked: 24, amount: 19200, status: 'Pending'),
    const PayrollRecord(workerName: 'Suresh Yadav', role: 'Welder', daysWorked: 22, amount: 20900, status: 'Paid'),
    const PayrollRecord(workerName: 'Vijay Singh', role: 'Carpenter', daysWorked: 26, amount: 19500, status: 'Pending'),
    const PayrollRecord(workerName: 'Mohammad Ali', role: 'Helper', daysWorked: 18, amount: 9000, status: 'Paid'),
  ];
});

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final records = ref.watch(payrollListProvider);

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            _buildSummaryCard(isDark),
            _buildSearchBar(isDark),
            Expanded(
              child: _buildPayrollList(records, isDark),
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

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
      child: const PMTextInput(
        hintText: 'Search worker',
        prefixIcon: Icon(Icons.search),
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
