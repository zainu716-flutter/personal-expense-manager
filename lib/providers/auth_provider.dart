import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Cached offline state ──────────────────────────────────
  static const _kUidKey   = 'cached_uid';
  static const _kEmailKey = 'cached_email';

  String? _cachedUid;
  String? _cachedEmail;

  // ── Connectivity ──────────────────────────────────────────
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  AuthProvider() {
    _loadCachedUser();
    _listenConnectivity();
  }

  // ─────────────────────────────────────────────────────────
  // Getters – prefer live Firebase user; fall back to cache
  // ─────────────────────────────────────────────────────────
  User?   get currentUser => _auth.currentUser;
  String? get userId      => _auth.currentUser?.uid   ?? _cachedUid;
  String? get userEmail   => _auth.currentUser?.email ?? _cachedEmail;
  bool    get isLoggedIn  => userId != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────
  // Sign Up  (requires connectivity)
  // ─────────────────────────────────────────────────────────
  Future<String?> signUp(String email, String password) async {
    if (!_isOnline) return 'No internet connection. Please connect and try again.';

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await _persistUser(cred.user);
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Login
  //   • Online  → Firebase auth, then cache credentials
  //   • Offline → validate against cached credentials only
  // ─────────────────────────────────────────────────────────
  Future<String?> login(String email, String password) async {
    if (!_isOnline) {
      return _offlineLogin(email.trim());
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await _persistUser(cred.user);
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Logout  – clears both Firebase session and local cache
  // ─────────────────────────────────────────────────────────
  Future<void> logout() async {
    if (_isOnline) {
      await _auth.signOut();
    }
    await _clearCachedUser();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // Offline login helper
  // ─────────────────────────────────────────────────────────
  String? _offlineLogin(String email) {
    if (_cachedUid == null || _cachedEmail == null) {
      return 'No offline session found. Please connect to the internet to log in.';
    }
    if (_cachedEmail!.toLowerCase() != email.toLowerCase()) {
      return 'Email does not match the cached offline session.';
    }
    // Credentials match the cached session – allow access
    notifyListeners();
    return null; // success
  }

  // ─────────────────────────────────────────────────────────
  // Persistence helpers
  // ─────────────────────────────────────────────────────────
  Future<void> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUid   = prefs.getString(_kUidKey);
    _cachedEmail = prefs.getString(_kEmailKey);
    notifyListeners();
  }

  Future<void> _persistUser(User? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUidKey,   user.uid);
    await prefs.setString(_kEmailKey, user.email ?? '');
    _cachedUid   = user.uid;
    _cachedEmail = user.email;
  }

  Future<void> _clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUidKey);
    await prefs.remove(_kEmailKey);
    _cachedUid   = null;
    _cachedEmail = null;
  }

  // ─────────────────────────────────────────────────────────
  // Connectivity watcher
  // ─────────────────────────────────────────────────────────
  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);

      // Re-sync Firebase state when coming back online
      if (wasOffline && _isOnline) {
        _syncOnReconnect();
      }
      notifyListeners();
    });
  }

  /// Called when the device reconnects.
  /// Forces Firebase to refresh the token so the live session
  /// stays in sync with the cached one.
  Future<void> _syncOnReconnect() async {
    try {
      await _auth.currentUser?.reload();
      if (_auth.currentUser != null) {
        await _persistUser(_auth.currentUser);
      }
      notifyListeners();
    } catch (_) {
      // Silently ignore – will retry on next reconnect
    }
  }

  // ─────────────────────────────────────────────────────────
  // Error messages
  // ─────────────────────────────────────────────────────────
  String _errorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}