import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_state_model.dart';
import '../models/log_model.dart';
import '../services/firebase_service.dart';

class DeviceProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  DeviceStateModel? _deviceState;
  StreamSubscription<DeviceStateModel>? _deviceSub;

  DeviceProvider(this._firebaseService);

  DeviceStateModel? get deviceState => _deviceState;
  bool get isOnline => _deviceState?.isOnline ?? false;
  int get batteryLevel => _deviceState?.batteryLevel ?? 0;

  void listenToDevice(String uid, String deviceId) {
    _deviceSub?.cancel();
    if (deviceId.isEmpty) {
      _deviceState = DeviceStateModel.initial('UNPAIRED');
      notifyListeners();
      return;
    }

    String lastHandledEvent = '';

    _deviceSub = _firebaseService.streamDeviceState(uid, deviceId).listen((state) {
      _deviceState = state;
      notifyListeners();

      if (state.lastEvent.isNotEmpty) {
        final String eventKey = '${state.lastEvent}_${state.lastEventCompartment}_${state.lastEventDetails}';
        if (eventKey != lastHandledEvent) {
          lastHandledEvent = eventKey;
          if (state.lastEvent == 'TAKEN' || state.lastEvent == 'MISSED') {
            final eventType = EventTypeExtension.fromString(state.lastEvent);
            int compId = state.lastEventCompartment;
            if (compId <= 0) {
              final regMatch = RegExp(r'C([1-6])').firstMatch(state.lastEventDetails);
              if (regMatch != null) {
                compId = int.parse(regMatch.group(1)!);
              } else {
                compId = 1;
              }
            }
            final log = LogModel(
              id: '',
              compartment: compId,
              timestamp: DateTime.now(),
              eventType: eventType,
              details: state.lastEventDetails.isNotEmpty ? state.lastEventDetails : 'ESP32 event: ${state.lastEvent}',
            );
            _firebaseService.addLog(uid, log);
          }
        }
      }
    }, onError: (_) {
      _deviceState = DeviceStateModel.initial(deviceId);
      notifyListeners();
    });
  }

  void stopListening() {
    _deviceSub?.cancel();
    _deviceState = null;
    notifyListeners();
  }

  CompartmentStatus? getCompartmentStatus(int compartmentId) {
    if (_deviceState == null) return null;
    try {
      return _deviceState!.compartmentStatus.firstWhere((c) => c.id == compartmentId);
    } catch (_) {
      return null;
    }
  }

  // Simulated hardware lid trigger helper (for manual/dev testing)
  Future<void> simulateLidTrigger({
    required String uid,
    required String deviceId,
    required int compartmentId,
    required bool isOpen,
  }) async {
    if (_deviceState == null || deviceId.isEmpty) return;

    final updatedStatus = _deviceState!.compartmentStatus.map((c) {
      if (c.id == compartmentId) {
        return CompartmentStatus(
          id: c.id,
          isOpen: isOpen,
          ledOn: isOpen ? false : c.ledOn,
          ledColor: isOpen ? 'OFF' : c.ledColor,
        );
      }
      return c;
    }).toList();

    await _saveUpdatedState(uid, deviceId, updatedStatus);
  }

  Future<void> updateCompartmentLedColor({
    required String uid,
    required String deviceId,
    required int compartmentId,
    required String color,
  }) async {
    if (deviceId.isEmpty) return;
    final cleanColor = color.toUpperCase();

    if (_deviceState != null) {
      final updatedStatus = _deviceState!.compartmentStatus.map((c) {
        if (c.id == compartmentId) {
          return CompartmentStatus(
            id: c.id,
            isOpen: c.isOpen,
            ledOn: cleanColor != 'OFF',
            ledColor: cleanColor,
          );
        }
        return c;
      }).toList();

      _deviceState = DeviceStateModel(
        deviceId: _deviceState!.deviceId,
        isOnline: _deviceState!.isOnline,
        batteryLevel: _deviceState!.batteryLevel,
        lastSeen: _deviceState!.lastSeen,
        compartmentStatus: updatedStatus,
        lastEvent: _deviceState!.lastEvent,
        lastEventDetails: _deviceState!.lastEventDetails,
      );
      notifyListeners();
    }

    await _firebaseService.updateCompartmentLedColor(deviceId, compartmentId, cleanColor);
    await _saveUpdatedState(uid, deviceId, _deviceState?.compartmentStatus ?? []);
  }

  // Simulated hardware LED state helper (GREEN = take dose, RED = wrong box opened, OFF = idle)
  Future<void> simulateLedColor({
    required String uid,
    required String deviceId,
    required int compartmentId,
    required String ledColor,
  }) async {
    await updateCompartmentLedColor(
      uid: uid,
      deviceId: deviceId,
      compartmentId: compartmentId,
      color: ledColor,
    );
  }

  Future<void> _saveUpdatedState(String uid, String deviceId, List<CompartmentStatus> updatedStatus) async {
    final updatedState = DeviceStateModel(
      deviceId: deviceId,
      isOnline: true,
      batteryLevel: _deviceState?.batteryLevel ?? 100,
      lastSeen: DateTime.now(),
      compartmentStatus: updatedStatus,
    );

    // Save to user sub-collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('deviceState')
        .doc(deviceId)
        .set(updatedState.toFirestore(), SetOptions(merge: true));

    // Also mirror to root /deviceState/{deviceId}
    await FirebaseFirestore.instance
        .collection('deviceState')
        .doc(deviceId)
        .set(updatedState.toFirestore(), SetOptions(merge: true));
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    super.dispose();
  }
}
