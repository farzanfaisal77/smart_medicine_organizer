import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  User? _authUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserModel?>? _userSub;

  AuthProvider(this._firebaseService) {
    _init();
  }

  User? get authUser => _authUser;
  UserModel? get userModel => _userModel;
  bool get isAuthenticated => _authUser != null;
  bool get isDevicePaired => _userModel?.deviceId.isNotEmpty ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _init() {
    _authSub = _firebaseService.authStateChanges.listen((user) {
      _authUser = user;
      notifyListeners();
      if (user != null) {
        _listenToUserProfile(user.uid);
      } else {
        _userSub?.cancel();
        _userModel = null;
      }
    });
  }

  void _listenToUserProfile(String uid) {
    _userSub?.cancel();
    _userSub = _firebaseService.streamUserProfile(uid).listen((userModel) {
      _userModel = userModel;
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _firebaseService.signInWithEmail(email, password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String deviceId,
  }) async {
    _setLoading(true);
    try {
      await _firebaseService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        deviceId: deviceId,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> quickStart([String deviceId = 'ESP32_001']) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      try {
        await _firebaseService.signUpWithEmail(
          email: 'esp32@organizer.com',
          password: 'esp32password',
          name: 'ESP32 User',
          deviceId: deviceId,
        );
      } catch (_) {
        await _firebaseService.signInWithEmail('esp32@organizer.com', 'esp32password');
      }
      _setLoading(false);
      return true;
    } catch (e) {
      try {
        await _firebaseService.signInAnonymously(deviceId);
        _setLoading(false);
        return true;
      } catch (err) {
        _setError(err.toString());
        _setLoading(false);
        return false;
      }
    }
  }

  Future<bool> pairDevice(String deviceId) async {
    if (_authUser == null) return false;
    _setLoading(true);
    try {
      await _firebaseService.updateDevicePairing(_authUser!.uid, deviceId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> updateSettings({
    bool? pushEnabled,
    bool? smsEnabled,
    int? volume,
    int? duration,
  }) async {
    if (_authUser == null || _userModel == null) return;
    final updates = <String, dynamic>{};
    if (pushEnabled != null) updates['pushNotificationsEnabled'] = pushEnabled;
    if (smsEnabled != null) updates['smsNotificationsEnabled'] = smsEnabled;
    if (volume != null) updates['buzzerVolume'] = volume;
    if (duration != null) updates['buzzerDuration'] = duration;

    await _firebaseService.updateUserProfile(_authUser!.uid, updates);
    if (volume != null || duration != null) {
      await _firebaseService.updateDeviceSettings(
        _authUser!.uid,
        _userModel!.deviceId,
        volume: volume,
        duration: duration,
      );
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
