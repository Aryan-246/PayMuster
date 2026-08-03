import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/user.dart';

class LocalUserRepository {
  static const String _storageKey = 'paymuster.local_users';
  static const String _rememberMeKey = 'paymuster.remembered_user';

  final Map<String, ({String password, User user})> _users = {};
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List;
        for (final item in list) {
          try {
            final map = Map<String, dynamic>.from(item as Map);
            final user = User.fromJson(map);
            final password = map['password'] as String;
            _users[user.email] = (password: password, user: user);
          } catch (e) {
            // Skip corrupted individual records
          }
        }
      } catch (e) {
        // Entire JSON is corrupted, skip
      }
    }

    _seedMockUsers();
    _isLoaded = true;
  }

  void _seedMockUsers() {
    final mockUsers = [
      (
        email: 'admin@paymuster.com',
        role: UserRole.superAdmin,
        name: 'Super Admin',
      ),
      (
        email: 'owner@paymuster.com',
        role: UserRole.owner,
        name: 'Company Owner',
      ),
      (
        email: 'manager@paymuster.com',
        role: UserRole.admin,
        name: 'Site Manager',
      ),
      (
        email: 'supervisor@paymuster.com',
        role: UserRole.supervisor,
        name: 'Supervisor',
      ),
      (
        email: 'worker@paymuster.com',
        role: UserRole.staff,
        name: 'Worker',
      ),
    ];

    for (var i = 0; i < mockUsers.length; i++) {
      final mockUser = mockUsers[i];
      if (!_users.containsKey(mockUser.email)) {
        _users[mockUser.email] = (
          password: 'Password@123',
          user: User(
            id: 'mock_user_$i',
            email: mockUser.email,
            role: mockUser.role,
            name: mockUser.name,
          ),
        );
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final customEntries = <Map<String, dynamic>>[];
    for (final entry in _users.entries) {
      customEntries.add({
        ...entry.value.user.toJson(),
        'password': entry.value.password,
      });
    }
    await prefs.setString(_storageKey, jsonEncode(customEntries));
  }

  Future<void> saveUser(User user, String password) async {
    _users[user.email] = (password: password, user: user);
    await save();
  }

  Future<void> updateUser(User user) async {
    if (_users.containsKey(user.email)) {
      final password = _users[user.email]!.password;
      _users[user.email] = (password: password, user: user);
      await save();
    }
  }

  Future<void> deleteUser(String email) async {
    if (_users.containsKey(email)) {
      _users.remove(email);
      await save();
    }
  }

  ({String password, User user})? findByEmail(String email) {
    return _users[email];
  }

  bool exists(String email) {
    return _users.containsKey(email);
  }

  Future<void> setRememberedUser(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove(_rememberMeKey);
    } else {
      await prefs.setString(_rememberMeKey, email);
    }
  }

  Future<String?> getRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberMeKey);
  }
}
