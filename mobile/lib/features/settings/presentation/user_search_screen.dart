import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../core/env/env.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../../auth/data/auth_provider.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  List<_UserResult> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await ref.read(authProvider).getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${Env.apiBaseUrl}/admin/users?q=${Uri.encodeComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 400) {
        throw Exception('Search failed');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> users = decoded['data'] ?? [];
      setState(() {
        _results = users.map((u) => _UserResult(
          id: u['id'] as String,
          name: u['name'] as String? ?? 'Unknown',
          email: u['email'] as String? ?? 'Unknown',
          role: u['role'] as String? ?? 'UNKNOWN',
        )).toList();
      });
    } catch (e) {
      setState(() => _results = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final surfaceColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Search Users', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PMSpacing.s4),
            child: PMTextInput(
              labelText: 'Search by name, email or ID',
              controller: _searchController,
              onChanged: (val) => _searchUsers(val),
              suffixIcon: const Icon(Icons.search),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'Search for users to view their profiles',
                      style: PMTypography.body.copyWith(color: textColor.withValues(alpha: 0.7)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: PMSpacing.s4),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: PMSpacing.s3),
                        color: surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: PMRadius.md,
                          side: BorderSide(color: isDark ? PMColors.borderDefaultDark : PMColors.borderDefaultLight),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(PMSpacing.s4),
                          leading: CircleAvatar(
                            backgroundColor: PMColors.brandPrimaryLight.withValues(alpha: 0.1),
                            child: Text(
                              result.name.substring(0, 1).toUpperCase(),
                              style: PMTypography.headline.copyWith(color: PMColors.brandPrimaryLight),
                            ),
                          ),
                          title: Text(result.name, style: PMTypography.headline.copyWith(color: textColor)),
                          subtitle: Text(result.email, style: PMTypography.body.copyWith(color: textColor.withValues(alpha: 0.7))),
                          trailing: Text(result.role, style: PMTypography.caption.copyWith(color: textColor)),
                          onTap: () {
                            context.push('/app/super-admin/user/${result.id}');
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserResult {
  final String id;
  final String name;
  final String email;
  final String role;

  const _UserResult({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}
