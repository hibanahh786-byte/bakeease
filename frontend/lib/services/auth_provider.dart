import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  String? _userRole;
  bool _needsOnboarding = false;
  bool _isApproved = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userRole => _userRole;
  bool get needsOnboarding => _needsOnboarding;
  bool get isApproved => _isApproved;

  Future<bool> login(String username, String password) async {
    try {
      final response = await _apiService.postPublic('users/login/', {
        'username': username,
        'password': password,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', response.data['access']);
      await prefs.setString('refresh_token', response.data['refresh']);

      // Fetch user role
      await fetchUserRole();

      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchUserRole() async {
    try {
      final response = await _apiService.get('users/me/');
      _userRole = response.data['role'];
      
      if (_userRole == 'BAKER') {
        final profile = response.data['baker_profile'];
        _needsOnboarding = profile == null || profile['fssai_number'] == null || profile['fssai_number'].toString().isEmpty;
        _isApproved = profile != null && profile['is_approved'] == true;
      } else {
        _needsOnboarding = false;
        _isApproved = false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', _userRole!);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_role');
    _isAuthenticated = false;
    _userRole = null;
    _isApproved = false;
    notifyListeners();
  }
}
