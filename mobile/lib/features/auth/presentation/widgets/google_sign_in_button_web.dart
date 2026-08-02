import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class PMGoogleSignInButton extends ConsumerWidget {
  final bool isLoading;

  const PMGoogleSignInButton({super.key, this.isLoading = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Official Google Identity Services Web Button
    return SizedBox(
      height: 48, // Match PMButton height
      width: double.infinity,
      child: web.renderButton(),
    );
  }
}
