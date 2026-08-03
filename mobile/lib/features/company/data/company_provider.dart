import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/env/env.dart';
import '../../auth/data/auth_provider.dart';

final companyProvider = Provider<CompanyApi>((ref) {
  return CompanyApi(ref);
});

class CompanyApi {
  final Ref ref;
  CompanyApi(this.ref);

  Future<String?> _getToken() async {
    return await ref.read(authProvider).getAccessToken();
  }

  Future<Map<String, dynamic>> lookupCompany(String code) async {
    final response = await http.get(
      Uri.parse('${Env.apiBaseUrl}/company/lookup?code=$code'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode >= 400) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error']['message'] ?? 'Failed to lookup company');
    }

    final decoded = jsonDecode(response.body);
    return decoded['data']; // { id: '...', name: '...' }
  }

  Future<void> joinCompany(String companyId, {String? notes}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${Env.apiBaseUrl}/company/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-company-id': companyId,
      },
      body: jsonEncode({
        'notes': notes,
      }),
    );

    if (response.statusCode >= 400) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error']['message'] ?? 'Failed to join company');
    }
  }
}
