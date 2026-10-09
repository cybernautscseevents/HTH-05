import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'mock_api_client.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _apiClient = ApiClient();
  final _mockApiClient = MockApiClient();

  String? _token;
  String? _role;
  String? _fullName;
  int? _userId;
  bool _isLoading = true;

  /// Set to true for offline demo/mock mode, false (default) for real backend.
  bool _useMockApi = false;

  String? get token => _token;
  String? get role => _role;
  String? get fullName => _fullName;
  int? get userId => _userId;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  bool get useMockApi => _useMockApi;
  ApiClient get apiClient => _apiClient;
  MockApiClient get mockApiClient => _mockApiClient;

  set useMockApi(bool value) {
    _useMockApi = value;
    notifyListeners();
  }

  AuthProvider({bool useMockApi = false}) : _useMockApi = useMockApi {
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      _token = await _storage.read(key: 'access_token');
      _role = await _storage.read(key: 'role');
      _fullName = await _storage.read(key: 'full_name');
      final userIdStr = await _storage.read(key: 'user_id');
      _userId = userIdStr != null ? int.tryParse(userIdStr) : null;
    } catch (_) {
      // Handle potential storage corruption gracefully.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(
    String username,
    String password,
    String expectedRole,
  ) async {
    _isLoading = true;
    notifyListeners();

    debugPrint('[AuthProvider.signIn] Starting login, useMock=$_useMockApi');

    try {
      late final LoginResponse response;

      if (_useMockApi) {
        response = await _mockApiClient.login(username, password);
      } else {
        response = await _apiClient.login(username, password);
      }

      debugPrint('[AuthProvider.signIn] Login response received, role=${response.staff.role}');

      final returnedRole = response.staff.role.toLowerCase();
      final expectedRoleLower = expectedRole.toLowerCase();

      bool matches = false;
      if (expectedRoleLower == 'doctor') {
        matches = returnedRole == 'doctor';
      } else if (expectedRoleLower == 'staff' ||
          expectedRoleLower == 'hospital staff') {
        matches = returnedRole == 'receptionist' || returnedRole == 'admin';
      }

      debugPrint('[AuthProvider.signIn] Role match: expected=$expectedRoleLower, returned=$returnedRole, matches=$matches');

      if (!matches) {
        throw ApiException(
          'This account has the role "${response.staff.role}" which does not '
          'match the selected portal. Please use the correct login.',
        );
      }

      _token = response.accessToken;
      _role = response.staff.role;
      // Backend returns username, not a display name — use it as fullName.
      _fullName = response.staff.username;
      _userId = response.staff.id;

      await _storage.write(key: 'access_token', value: _token);
      await _storage.write(key: 'role', value: _role);
      await _storage.write(key: 'full_name', value: _fullName);
      await _storage.write(key: 'user_id', value: _userId.toString());

      debugPrint('[AuthProvider.signIn] Session stored successfully, role=$_role');
    } catch (e) {
      debugPrint('[AuthProvider.signIn] Failed with ${e.runtimeType}');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    _token = null;
    _role = null;
    _fullName = null;
    _userId = null;

    try {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'role');
      await _storage.delete(key: 'full_name');
      await _storage.delete(key: 'user_id');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
