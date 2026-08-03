import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/env/env.dart';
import '../domain/user.dart';
import 'auth_provider.dart';

class RemoteAuthProvider implements AuthProviderBase {
  static const String _userStorageKey = 'paymuster.auth.user';
  static const String _accessTokenKey = 'paymuster.auth.access_token';
  static const String _refreshTokenKey = 'paymuster.auth.refresh_token';

  bool _googleInitialized = false;

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final baseUrl = '${Env.apiBaseUrl}/auth';
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      throw AuthApiException(
        'INVALID_RESPONSE',
        'Server error: Expected JSON but received $contentType. Status: ${response.statusCode}',
        response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final errorData = decoded['error'] as Map<String, dynamic>?;
      final code = errorData?['code'] as String? ?? 'UNKNOWN';
      final message = errorData?['message'] as String? ?? 'Authentication failed.';
      throw AuthApiException(code, message, response.statusCode);
    }
    return decoded;
  }

  Future<void> _storeSession(
    Map<String, dynamic> payload, {
    required String? accessToken,
    required String? refreshToken,
  }) async {
    final prefs = await _prefs();
    if (payload['user'] != null) {
      await prefs.setString(_userStorageKey, jsonEncode(payload['user']));
    }
    if (accessToken != null) {
      await prefs.setString(_accessTokenKey, accessToken);
    }
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await _prefs();
    await prefs.remove(_userStorageKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  User _buildUser(Map<String, dynamic> payload) {
    final rawUser = payload['user'] as Map<String, dynamic>? ?? payload;
    final roleValue = (rawUser['role'] as String? ?? 'staff').toLowerCase();
    final role = switch (roleValue) {
      'superadmin' || 'super_admin' => UserRole.superAdmin,
      'owner' => UserRole.owner,
      'admin' => UserRole.admin,
      'supervisor' => UserRole.supervisor,
      'accountant' => UserRole.accountant,
      'viewer' => UserRole.viewer,
      _ => UserRole.staff,
    };

    return User(
      id: rawUser['id'] as String,
      email: rawUser['email'] as String,
      role: role,
      organizationId: rawUser['orgId'] as String? ?? rawUser['organizationId'] as String?,
      name: rawUser['name'] as String?,
    );
  }

  @override
  Future<User> signInWithEmail(String email, String password) async {
    final payload = await _post('/login', {
      'email': email,
      'password': password,
      'rememberMe': true,
    });
    final user = _buildUser(payload);
    await _storeSession(
      payload,
      accessToken: payload['accessToken'] as String?,
      refreshToken: payload['refreshToken'] as String?,
    );
    return user;
  }

  @override
  Future<User> signUpWithEmail(String email, String password, String name) async {
    final payload = await _post('/signup', {
      'email': email,
      'password': password,
      'name': name,
    });
    return _buildUser(payload);
  }

  @override
  Future<void> verifyEmail(String email, String otp) async {
    await _post('/verify-email', {
      'email': email,
      'otp': otp,
    });
  }

  @override
  Future<void> resendVerification(String email) async {
    await _post('/resend-verification', {
      'email': email,
    });
  }

  @override
  Future<void> resetPasswordWithOtp(String email, String otp, String newPassword) async {
    await _post('/reset-password', {
      'email': email,
      'otp': otp,
      'password': newPassword,
    });
  }

  @override
  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      throw Exception('Google Sign-In is not available in the web client yet.');
    }

    final clientId = Env.googleWebClientId.isNotEmpty
        ? Env.googleWebClientId
        : Env.googleAndroidClientId;
    if (clientId.isEmpty) {
      throw Exception('Google Sign-In is temporarily unavailable.');
    }

    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(clientId: clientId);
      _googleInitialized = true;
    }

    final googleUser = await GoogleSignIn.instance.authenticate(
      scopeHint: ['email', 'profile'],
    );
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google Sign-In is temporarily unavailable.');
    }

    final payload = await _post('/google', {
      'idToken': idToken,
      'email': googleUser.email,
      'name': googleUser.displayName,
    });
    final user = _buildUser(payload);
    await _storeSession(
      payload,
      accessToken: payload['accessToken'] as String?,
      refreshToken: payload['refreshToken'] as String?,
    );
    return user;
  }

  @override
  Future<User> signInWithApple() async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _clearSession();
  }

  @override
  Future<void> requestDeleteAccountOtp(String password) async {
    final prefs = await _prefs();
    final accessToken = prefs.getString(_accessTokenKey);
    
    if (accessToken != null) {
      final baseUrl = '${Env.apiBaseUrl}/auth';
      final response = await http.post(
        Uri.parse('$baseUrl/account/delete-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'password': password}),
      );
      
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('application/json')) {
        throw AuthApiException(
          'INVALID_RESPONSE',
          'Server error: Expected JSON but received $contentType. Status: ${response.statusCode}',
          response.statusCode,
        );
      }

      if (response.statusCode >= 400) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = decoded['error'] as Map<String, dynamic>?;
        final code = errorData?['code'] as String? ?? 'UNKNOWN';
        final message = errorData?['message'] as String? ?? 'Failed to request account deletion.';
        throw AuthApiException(code, message, response.statusCode);
      }
    }
  }

  @override
  Future<void> verifyDeleteAccountOtp(String otp) async {
    final prefs = await _prefs();
    final accessToken = prefs.getString(_accessTokenKey);
    
    if (accessToken != null) {
      final baseUrl = '${Env.apiBaseUrl}/auth';
      final response = await http.post(
        Uri.parse('$baseUrl/account/verify-delete-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'otp': otp}),
      );
      
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('application/json')) {
        throw AuthApiException(
          'INVALID_RESPONSE',
          'Server error: Expected JSON but received $contentType. Status: ${response.statusCode}',
          response.statusCode,
        );
      }
      
      if (response.statusCode >= 400) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = decoded['error'] as Map<String, dynamic>?;
        final code = errorData?['code'] as String? ?? 'UNKNOWN';
        final message = errorData?['message'] as String? ?? 'Failed to verify OTP.';
        throw AuthApiException(code, message, response.statusCode);
      }
    }
  }

  @override
  Future<void> deleteAccount(String otp) async {
    final prefs = await _prefs();
    final accessToken = prefs.getString(_accessTokenKey);
    
    if (accessToken != null) {
      final baseUrl = '${Env.apiBaseUrl}/auth';
      final response = await http.delete(
        Uri.parse('$baseUrl/account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'otp': otp}),
      );
      
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('application/json')) {
        throw AuthApiException(
          'INVALID_RESPONSE',
          'Server error: Expected JSON but received $contentType. Status: ${response.statusCode}',
          response.statusCode,
        );
      }
      
      if (response.statusCode >= 400) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final errorData = decoded['error'] as Map<String, dynamic>?;
        final code = errorData?['code'] as String? ?? 'UNKNOWN';
        final message = errorData?['message'] as String? ?? 'Failed to delete account.';
        throw AuthApiException(code, message, response.statusCode);
      }
      
      await _clearSession();
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    await _post('/forgot-password', {'email': email});
  }

  @override
  Future<User?> getCurrentUser() async {
    final prefs = await _prefs();
    final rawUser = prefs.getString(_userStorageKey);
    if (rawUser == null) {
      return null;
    }

    final userJson = jsonDecode(rawUser) as Map<String, dynamic>;
    return User.fromJson(userJson);
  }

  @override
  Future<User> fetchMe() async {
    final prefs = await _prefs();
    final accessToken = prefs.getString(_accessTokenKey);
    if (accessToken == null) throw Exception('Not authenticated');

    final baseUrl = '${Env.apiBaseUrl}/auth';
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final errorData = decoded['error'] as Map<String, dynamic>?;
      final code = errorData?['code'] as String? ?? 'UNKNOWN';
      final message = errorData?['message'] as String? ?? 'Failed to fetch user info.';
      throw AuthApiException(code, message, response.statusCode);
    }

    final user = _buildUser(decoded);
    await updateUser(user);
    return user;
  }

  @override
  Future<String?> getAccessToken() async {
    final prefs = await _prefs();
    return prefs.getString(_accessTokenKey);
  }

  @override
  Future<void> updateUser(User user) async {
    final prefs = await _prefs();
    await prefs.setString(_userStorageKey, jsonEncode(user.toJson()));
  }
}

/// Typed exception for backend API errors, carrying the error code.
class AuthApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  const AuthApiException(this.code, this.message, this.statusCode);

  @override
  String toString() => message;
}

final remoteAuthProvider = Provider<AuthProviderBase>((ref) {
  return RemoteAuthProvider();
});
