import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _emailKey = 'user_email';
  static const String _passwordKey = 'user_password';
  static const String _isLoggedInKey = 'is_logged_in';

  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  Future<bool> signUp(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingEmail = prefs.getString(_emailKey);

      if (existingEmail != null) {
        return false; // User already exists
      }

      await prefs.setString(_emailKey, email);
      await prefs.setString(_passwordKey, password);
      return true;
    } catch (e) {
      print('Error during sign up: $e');
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedEmail = prefs.getString(_emailKey);
      final storedPassword = prefs.getString(_passwordKey);

      if (storedEmail == email && storedPassword == password) {
        await prefs.setBool(_isLoggedInKey, true);
        return true;
      }
      return false;
    } catch (e) {
      print('Error during sign in: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, false);
    } catch (e) {
      print('Error during sign out: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }
}
