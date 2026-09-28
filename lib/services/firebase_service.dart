import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/medicine_model.dart';
import '../models/log_model.dart';
import '../models/device_state_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ------------------ AUTH METHODS ------------------
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        // If user not found in Auth, automatically create new user account & pair device
        return await signUpWithEmail(
          email: cleanEmail,
          password: password,
          name: 'User',
          deviceId: 'ESP32_001',
        );
      }
      rethrow;
    }

    if (cred.user != null) {
      final userDoc = await _db.collection('users').doc(cred.user!.uid).get();
      String devId = 'ESP32_001';
      if (userDoc.exists && userDoc.data() != null) {
        devId = (userDoc.data()!['deviceId'] ?? 'ESP32_001').toString();
        if (devId.isEmpty) devId = 'ESP32_001';
      }
      final userModel = UserModel(
        uid: cred.user!.uid,
        email: cleanEmail,
        name: (userDoc.data()?['name'] ?? 'User').toString(),
        deviceId: devId,
      );
      await _db.collection('users').doc(cred.user!.uid).set(userModel.toMap(), SetOptions(merge: true));
      await initializeDeviceState(cred.user!.uid, devId);
    }

    return cred;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String deviceId,
  }) async {
    final cleanEmail = email.trim();
    final cleanDeviceId = deviceId.trim().toUpperCase().isEmpty ? 'ESP32_001' : deviceId.trim().toUpperCase();
    UserCredential cred;

    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // If email already exists in Auth, sign in and repair/recreate the deleted Firestore document
        cred = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    if (cred.user != null) {
      final userModel = UserModel(
        uid: cred.user!.uid,
        email: cleanEmail,
        name: name.trim().isEmpty ? 'User' : name.trim(),
        deviceId: cleanDeviceId,
      );
      await _db.collection('users').doc(cred.user!.uid).set(userModel.toMap(), SetOptions(merge: true));
      await initializeDeviceState(cred.user!.uid, cleanDeviceId);
    }

    return cred;
  }

  Future<UserCredential> signInAnonymously(String deviceId) async {
    final cleanDeviceId = deviceId.trim().toUpperCase().isEmpty ? 'ESP32_001' : deviceId.trim().toUpperCase();
    UserCredential cred;
    try {
      cred = await _auth.signInAnonymously();
    } catch (_) {
      final genEmail = 'user_${DateTime.now().millisecondsSinceEpoch}@organizer.com';
      cred = await _auth.createUserWithEmailAndPassword(
        email: genEmail,
        password: 'esp32password',
      );
    }

    if (cred.user != null) {
      final userModel = UserModel(
        uid: cred.user!.uid,
        email: cred.user!.email ?? 'esp32@organizer.com',
        name: 'ESP32 User',
        deviceId: cleanDeviceId,
      );
      await _db.collection('users').doc(cred.user!.uid).set(userModel.toMap(), SetOptions(merge: true));
      await initializeDeviceState(cred.user!.uid, cleanDeviceId);
    }
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ------------------ USER PROFILE & PAIRING ------------------
  Stream<UserModel?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(uid, doc.data()!);
      } else {
        // Automatically repair/recreate missing user document if deleted from Firestore
        final defaultUser = UserModel(
          uid: uid,
          email: _auth.currentUser?.email ?? 'user@organizer.com',
          name: _auth.currentUser?.displayName ?? 'User',
          deviceId: 'ESP32_001',
        );
        _db.collection('users').doc(uid).set(defaultUser.toMap(), SetOptions(merge: true));
        initializeDeviceState(uid, 'ESP32_001');
        return defaultUser;
      }
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> updateDevicePairing(String uid, String deviceId) async {
    final cleanId = deviceId.trim().toUpperCase();
    await _db.collection('users').doc(uid).update({'deviceId': cleanId});
    await initializeDeviceState(uid, cleanId);
  }

  Future<void> initializeDeviceState(String uid, String deviceId) async {
    final initialMap = DeviceStateModel.initial(deviceId).toFirestore();
    await _db
        .collection('users')
        .doc(uid)
        .collection('deviceState')
        .doc(deviceId)
        .set(initialMap, SetOptions(merge: true));

    // Write to top level /deviceState/{deviceId} for direct ESP32 sync
    await _db.collection('deviceState').doc(deviceId).set(initialMap, SetOptions(merge: true));
  }

  // ------------------ MEDICINES METHOD ------------------
  Stream<List<MedicineModel>> streamMedicines(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MedicineModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addMedicine(String uid, MedicineModel medicine) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .add(medicine.toFirestore());
  }

  Future<void> updateMedicine(String uid, MedicineModel medicine) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc(medicine.id)
        .update(medicine.toFirestore());
  }

  Future<void> discontinueMedicine(String uid, String medicineId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc(medicineId)
        .update({'active': false});
  }

  Future<void> deleteMedicine(String uid, String medicineId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc(medicineId)
        .delete();
  }

  // ------------------ DEVICE STATE LISTENER & CONFIG ------------------
  Stream<DeviceStateModel> streamDeviceState(String uid, String deviceId) {
    if (deviceId.isEmpty) {
      return Stream.value(DeviceStateModel.initial('UNPAIRED'));
    }

    return _db
        .collection('deviceState')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return DeviceStateModel.fromFirestore(doc);
      }
      return DeviceStateModel.initial(deviceId);
    });
  }

  Future<void> updateDeviceSettings(String uid, String deviceId, {int? volume, int? duration}) async {
    final updates = <String, dynamic>{};
    if (volume != null) updates['buzzerVolume'] = volume;
    if (duration != null) updates['buzzerDuration'] = duration;

    await updateUserProfile(uid, updates);

    if (deviceId.isNotEmpty) {
      await _db.collection('deviceState').doc(deviceId).set(updates, SetOptions(merge: true));
    }
  }

  Future<void> updateCompartmentLedColor(String deviceId, int compartmentId, String color) async {
    if (deviceId.isEmpty) return;
    final String cleanColor = color.toUpperCase();
    final updates = <String, dynamic>{
      'c${compartmentId}Color': cleanColor,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    await _db.collection('deviceState').doc(deviceId).set(updates, SetOptions(merge: true));
  }

  Future<void> updateNextDoseInDeviceState(String deviceId, {
    required String medicineName,
    required String time,
    required int compartment,
    required String dosage,
    required String instructions,
    required bool hasPendingDose,
    int buzzerVolume = 80,
    int buzzerDuration = 30,
  }) async {
    if (deviceId.isEmpty) return;

    final nextDoseData = {
      'nextMedicineName': medicineName,
      'nextDoseTime': time,
      'nextCompartment': compartment,
      'nextDosage': dosage,
      'nextInstructions': instructions,
      'hasPendingDose': hasPendingDose,
      'buzzerVolume': buzzerVolume,
      'buzzerDuration': buzzerDuration,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await _db
        .collection('deviceState')
        .doc(deviceId)
        .set(nextDoseData, SetOptions(merge: true));
  }

  // ------------------ LOGS STREAM & ACTIONS ------------------
  Stream<List<LogModel>> streamLogs(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LogModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> addLog(String uid, LogModel log) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('logs')
        .add(log.toFirestore());
  }
}
