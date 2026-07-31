import 'package:flutter/material.dart';
import '../../theme/paymuster_tokens.dart';
import '../../components/layout/pm_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: PMSpacing.s6),
              _buildWorkforceCard(isDark),
              const SizedBox(height: PMSpacing.s6),
              _buildQuickActions(isDark),
              const SizedBox(height: PMSpacing.s6),
              _buildAiInsightCard(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good Morning, Aryan 👋', style: PMTypography.headline),
            const SizedBox(height: PMSpacing.s1),
            Row(
              children: [
                Text(
                  'Site: Mohali Tower A',
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
        Stack(
          children: [
            Icon(
              Icons.notifications_none,
              color: isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight,
              size: 28,
            ),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: PMColors.statusDangerDark,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkforceCard(bool isDark) {
    return PMCard.standard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s Workforce', style: PMTypography.headline),
                  const SizedBox(height: PMSpacing.s1),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: PMColors.statusSuccessDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: PMSpacing.s1),
                      Text(
                        'Updated just now',
                        style: PMTypography.caption.copyWith(
                          color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.cloud_outlined,
                    size: 20,
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                  const SizedBox(width: PMSpacing.s2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('28', style: PMTypography.headline),
                          Text('°', style: PMTypography.caption),
                        ],
                      ),
                      Text(
                        'Partly Cloudy',
                        style: PMTypography.caption.copyWith(
                          color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: PMSpacing.s6),
          Row(
            children: [
              // Circle Chart Placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PMColors.brandPrimaryDark,
                    width: 8,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('284', style: PMTypography.display),
                      Text(
                        'Total Workers',
                        style: PMTypography.caption.copyWith(
                          color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: PMSpacing.s6),
              // Stats
              Expanded(
                child: Column(
                  children: [
                    _buildStatRow('Present', '284', PMColors.statusSuccessDark, isDark),
                    const SizedBox(height: PMSpacing.s3),
                    _buildStatRow('Absent', '14', PMColors.statusDangerDark, isDark),
                    const SizedBox(height: PMSpacing.s3),
                    _buildStatRow('Half Day', '8', PMColors.statusWarningDark, isDark),
                    const SizedBox(height: PMSpacing.s3),
                    _buildStatRow('On Leave', '6', isDark ? PMColors.textTertiaryDark : PMColors.textTertiaryLight, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PMSpacing.s5),
          Divider(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
          const SizedBox(height: PMSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sync,
                    size: 14,
                    color: PMColors.statusSuccessDark,
                  ),
                  const SizedBox(width: PMSpacing.s1),
                  Text(
                    'Sync: Online',
                    style: PMTypography.caption.copyWith(
                      color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              Text(
                'Battery: 78%',
                style: PMTypography.caption.copyWith(
                  color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: PMTypography.body.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: PMTypography.label.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Actions', style: PMTypography.headline),
            Text(
              'View All',
              style: PMTypography.label.copyWith(
                color: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: PMSpacing.s4),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: PMSpacing.s4,
          crossAxisSpacing: PMSpacing.s2,
          childAspectRatio: 0.8,
          children: [
            _buildActionItem(Icons.how_to_reg, 'Review\nAttendance', isDark, isAccent: true),
            _buildActionItem(Icons.fact_check, 'Mark\nAttendance', isDark),
            _buildActionItem(Icons.person_add, 'Add\nWorker', isDark),
            _buildActionItem(Icons.payments, 'Payroll', isDark),
            _buildActionItem(Icons.receipt_long, 'Expenses', isDark),
            _buildActionItem(Icons.approval, 'Approvals', isDark),
            _buildActionItem(Icons.more_horiz, 'More', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, bool isDark, {bool isAccent = false}) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isAccent 
                ? (isDark ? PMColors.brandContainerDark : PMColors.brandContainerLight)
                : (isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: isAccent 
                ? (isDark ? PMColors.brandOnContainerDark : PMColors.brandOnContainerLight)
                : (isDark ? PMColors.textPrimaryDark : PMColors.textPrimaryLight),
          ),
        ),
        const SizedBox(height: PMSpacing.s2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: PMTypography.caption.copyWith(
            color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightCard(bool isDark) {
    return PMCard.priority(
      accentColor: PMColors.brandPrimaryDark,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(PMSpacing.s2),
            decoration: BoxDecoration(
              color: isDark ? PMColors.brandContainerDark : PMColors.brandContainerLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              color: isDark ? PMColors.brandOnContainerDark : PMColors.brandOnContainerLight,
              size: 24,
            ),
          ),
          const SizedBox(width: PMSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('AI Insight', style: PMTypography.label),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? PMColors.bgRaisedDark : PMColors.bgRaisedLight,
                        borderRadius: PMRadius.full,
                      ),
                      child: Text('BETA', style: PMTypography.overline),
                    ),
                  ],
                ),
                const SizedBox(height: PMSpacing.s2),
                Text(
                  '12 workers are absent today',
                  style: PMTypography.headline,
                ),
                const SizedBox(height: PMSpacing.s1),
                Text(
                  'AI suggests replacement from Site B',
                  style: PMTypography.body.copyWith(
                    color: isDark ? PMColors.textSecondaryDark : PMColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: PMSpacing.s3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'View Suggestions',
                    style: PMTypography.label.copyWith(
                      color: isDark ? PMColors.brandPrimaryDark : PMColors.brandPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
