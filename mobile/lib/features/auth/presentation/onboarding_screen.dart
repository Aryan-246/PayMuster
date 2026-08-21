import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import 'auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Construction Management\nReimagined',
      description:
          'Track your workforce, manage sites, and handle payroll all from your pocket.',
      icon: Icons.domain,
    ),
    _OnboardingPage(
      title: 'Real-time\nWorkforce Tracking',
      description:
          'Know exactly who is on site and when. Live roll calls and attendance tracking.',
      icon: Icons.groups,
    ),
    _OnboardingPage(
      title: 'Automated\nPayroll System',
      description:
          'Seamless integration with attendance ensures accurate and timely payments.',
      icon: Icons.account_balance_wallet,
    ),
  ];

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);
    try {
      await ref.read(authControllerProvider.notifier).markOnboardingSeen();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save onboarding progress. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final descColor = isDark
        ? PMColors.textSecondaryDark
        : PMColors.textSecondaryLight;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(page.icon, size: 80, color: PMColors.brandPrimaryDark),
                    const SizedBox(height: 48),
                    Text(
                      page.title,
                      style: PMTypography.displayLarge.copyWith(
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      page.description,
                      style: PMTypography.bodyLarge.copyWith(color: descColor),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 48,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? PMColors.brandPrimaryDark
                            : descColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                FloatingActionButton(
                  onPressed: _isCompleting
                      ? null
                      : () {
                          if (_currentPage == _pages.length - 1) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                  backgroundColor: PMColors.brandPrimaryDark,
                  child: Icon(
                    _currentPage == _pages.length - 1
                        ? Icons.check
                        : Icons.arrow_forward,
                    color: Colors.white,
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

class _OnboardingPage {
  final String title;
  final String description;
  final IconData icon;

  _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });
}
