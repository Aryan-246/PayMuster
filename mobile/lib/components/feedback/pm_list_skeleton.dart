import 'package:flutter/material.dart';
import '../../theme/paymuster_tokens.dart';
import '../layout/pm_card.dart';
import 'pm_skeleton.dart';

class PMListSkeleton extends StatelessWidget {
  final int itemCount;

  const PMListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s5, vertical: PMSpacing.s4),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: PMSpacing.s3),
      itemBuilder: (context, index) {
        return PMCard.standard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PMSkeleton.circular(size: 48),
              const SizedBox(width: PMSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PMSkeleton.text(width: 150, height: 20),
                    const SizedBox(height: PMSpacing.s2),
                    PMSkeleton.text(width: 100, height: 14),
                  ],
                ),
              ),
              PMSkeleton(width: 60, height: 24, borderRadius: PMRadius.sm),
            ],
          ),
        );
      },
    );
  }
}
