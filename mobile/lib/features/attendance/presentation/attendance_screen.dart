import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/layout/pm_card.dart';
import '../../../components/feedback/pm_list_skeleton.dart';
import '../../../components/foundation/pm_button.dart';
import '../../../components/foundation/pm_text_input.dart';
import 'attendance_controller.dart';

class AttendanceSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void updateQuery(String query) => state = query;
}

final attendanceSearchProvider = NotifierProvider<AttendanceSearchNotifier, String>(() => AttendanceSearchNotifier());

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceControllerProvider);
    final searchQuery = ref.watch(attendanceSearchProvider).toLowerCase();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark, ref),
            _buildSearchBar(isDark, ref),
            _buildSummaryBar(state, isDark),
            Expanded(
              child: state.isLoading
                  ? const PMListSkeleton()
                  : _buildAttendanceList(state, searchQuery, isDark, ref),
            ),
            _buildSubmitButton(isDark),
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
        onChanged: (val) => ref.read(attendanceSearchProvider.notifier).updateQuery(val),
      ),
    );
  }

  Widget _buildHeader(bool isDark, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PMSpacing.s5, PMSpacing.s4, PMSpacing.s5, PMSpacing.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark Attendance', style: PMTypography.title),
              const SizedBox(height: PMSpacing.s1),
              Row(
                children: [
                  Text(
                    'Mohali Tower A',
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
          TextButton(
            onPressed: () {
              ref.read(attendanceControllerProvider.notifier).markAllPresent();
            },
            child: Text(
              'Mark All Present',
              style: PMTypography.label.copyWith(
                color: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(AttendanceState state, bool isDark) {
    if (state.isLoading) return const SizedBox();

    int present = 0;
    int absent = 0;
    for (var rec in state.records.values) {
      if (rec.status == 'Present') present++;
      if (rec.status == 'Absent') absent++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${state.workers.length} Total Workers',
            style: PMTypography.label,
          ),
          Row(
            children: [
              _buildSummaryDot('Present: $present', PMColors.statusSuccessDark, isDark),
              const SizedBox(width: PMSpacing.s3),
              _buildSummaryDot('Absent: $absent', PMColors.statusDangerDark, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDot(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: PMSpacing.s1),
        Text(
          label,
          style: PMTypography.caption.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList(AttendanceState state, String searchQuery, bool isDark, WidgetRef ref) {
    if (state.workers.isEmpty) {
      return Center(
        child: Text('No workers found.', style: PMTypography.body.copyWith(color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight)),
      );
    }
    
    final filtered = state.workers.where((w) => w.fullName.toLowerCase().contains(searchQuery) || w.role.toLowerCase().contains(searchQuery)).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text('No workers match the search.', style: PMTypography.body.copyWith(color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s2),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final worker = filtered[index];
        final record = state.records[worker.id];
        final status = record?.status ?? 'Absent';

        return Padding(
          padding: const EdgeInsets.only(bottom: PMSpacing.s3),
          child: Dismissible(
            key: ValueKey(worker.id),
            background: Container(
              decoration: BoxDecoration(
                color: PMColors.statusSuccessDark,
                borderRadius: PMRadius.lg,
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s4),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: PMColors.statusDangerDark,
                borderRadius: PMRadius.lg,
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s4),
              child: const Icon(Icons.close, color: Colors.white, size: 32),
            ),
            onDismissed: (direction) {
              if (direction == DismissDirection.startToEnd) {
                ref.read(attendanceControllerProvider.notifier).markAttendance(worker.id, 'Present');
              } else {
                ref.read(attendanceControllerProvider.notifier).markAttendance(worker.id, 'Absent');
              }
            },
            child: PMCard.standard(
              child: Row(
                children: [
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(worker.fullName, style: PMTypography.headline),
                        const SizedBox(height: PMSpacing.s1),
                        Text(
                          worker.role,
                          style: PMTypography.caption.copyWith(
                            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(status, isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPill(String status, bool isDark) {
    Color bgColor;
    Color textColor;
    
    if (status == 'Present') {
      bgColor = isDark ? PMColors.statusSuccessDark : PMColors.statusSuccessLight;
      textColor = PMColors.textInverseLight;
    } else {
      bgColor = isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight;
      textColor = isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s3, vertical: PMSpacing.s1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: PMRadius.full,
      ),
      child: Text(
        status.toUpperCase(),
        style: PMTypography.overline.copyWith(color: textColor),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(PMSpacing.s5),
      decoration: BoxDecoration(
        color: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
        boxShadow: isDark ? PMElevation.floatingDark : PMElevation.floatingLight,
      ),
      child: PMButton.primary(
        label: 'Submit Attendance',
        onPressed: () {},
      ),
    );
  }
}
