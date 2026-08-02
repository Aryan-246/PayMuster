import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../components/foundation/pm_button.dart';
import '../auth_controller.dart';

class PMGoogleSignInButton extends ConsumerWidget {
  final bool isLoading;

  const PMGoogleSignInButton({super.key, this.isLoading = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PMButton.secondary(
      label: 'Google',
      icon: Icons.g_mobiledata,
      isLoading: isLoading,
      onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
    );
  }
}
