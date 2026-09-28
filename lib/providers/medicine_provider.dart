import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine_model.dart';
import '../models/log_model.dart';
import '../services/firebase_service.dart';

class DoseScheduleItem {
  final MedicineModel medicine;
  final String time; // e.g. "13:00"
  final DateTime scheduledDateTime;
  final String status; // 'Pending', 'Taken', 'Missed'

  DoseScheduleItem({
    required this.medicine,
    required this.time,
    required this.scheduledDateTime,
    required this.status,
  });
}

class MedicineProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  List<MedicineModel> _medicines = [];
  List<LogModel> _latestLogs = [];
  bool _isLoading = false;
  StreamSubscription<List<MedicineModel>>? _medSub;
  Timer? _scheduleSyncTimer;

  MedicineProvider(this._firebaseService);

  List<MedicineModel> get medicines => _medicines;
  List<MedicineModel> get activeMedicines =>
      _medicines.where((m) => m.active).toList();
  bool get isLoading => _isLoading;

  void setLogs(List<LogModel> logs, {String? deviceId}) {
    _latestLogs = logs;
    notifyListeners();
    if (deviceId != null && deviceId.isNotEmpty) {
      syncNextDoseToDevice(deviceId, logs: _latestLogs);
    }
  }

  void listenToMedicines(String uid, {String? deviceId}) {
    _medSub?.cancel();
    _scheduleSyncTimer?.cancel();

    _isLoading = true;
    notifyListeners();

    _medSub = _firebaseService.streamMedicines(uid).listen((list) {
      _medicines = list;
      _isLoading = false;
      notifyListeners();
      if (deviceId != null && deviceId.isNotEmpty) {
        syncNextDoseToDevice(deviceId);
      }
    }, onError: (err) {
      _isLoading = false;
      notifyListeners();
    });

    // Re-evaluate and sync next dose every 5 seconds to guarantee accurate hardware progression
    if (deviceId != null && deviceId.isNotEmpty) {
      _scheduleSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        syncNextDoseToDevice(deviceId);
      });
    }
  }

  void stopListening() {
    _medSub?.cancel();
    _scheduleSyncTimer?.cancel();
    _medicines = [];
    notifyListeners();
  }

  MedicineModel? getMedicineForCompartment(int compartmentId) {
    try {
      return _medicines.firstWhere(
        (m) => m.active && m.compartment == compartmentId,
      );
    } catch (_) {
      return null;
    }
  }

  bool isCompartmentOccupied(int compartmentId, {String? excludeMedicineId}) {
    return _medicines.any((m) =>
        m.active &&
        m.compartment == compartmentId &&
        m.id != excludeMedicineId);
  }

  Future<bool> addMedicine(String uid, MedicineModel medicine, {String? deviceId}) async {
    try {
      await _firebaseService.addMedicine(uid, medicine);
      if (deviceId != null && deviceId.isNotEmpty) {
        await syncNextDoseToDevice(deviceId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateMedicine(String uid, MedicineModel medicine, {String? deviceId}) async {
    try {
      await _firebaseService.updateMedicine(uid, medicine);
      if (deviceId != null && deviceId.isNotEmpty) {
        await syncNextDoseToDevice(deviceId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> discontinueMedicine(String uid, String medicineId, {String? deviceId}) async {
    try {
      await _firebaseService.discontinueMedicine(uid, medicineId);
      if (deviceId != null && deviceId.isNotEmpty) {
        await syncNextDoseToDevice(deviceId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Robust DateTime parser supporting 24h ("13:00") and 12h AM/PM ("1:00 PM", "08:00 AM")
  DateTime? parseTimeString(String timeStr, DateTime baseDate) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final bool isPM = clean.contains('PM');
      final bool isAM = clean.contains('AM');

      final numericPart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = numericPart.split(':');
      if (parts.length < 2) return null;

      int hour = int.parse(parts[0].trim());
      int minute = int.parse(parts[1].trim());

      if (isPM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  List<DoseScheduleItem> getTodaySchedule([List<LogModel>? logs]) {
    final now = DateTime.now();
    final currentDayShort = DateFormat('EEE').format(now); // e.g. "Mon"
    final currentDayFull = DateFormat('EEEE').format(now); // e.g. "Monday"

    final List<DoseScheduleItem> items = [];

    for (var med in activeMedicines) {
      final matchesDay = med.days.any((d) =>
          d.toLowerCase() == currentDayShort.toLowerCase() ||
          d.toLowerCase() == currentDayFull.toLowerCase() ||
          d.toLowerCase() == 'daily');

      if (!matchesDay) continue;

      for (var t in med.times) {
        final scheduledDt = parseTimeString(t, now);
        if (scheduledDt == null) continue;

        String status = 'Pending';
        
        // Check if there is a log for today matching this compartment
        bool isTaken = false;
        bool isMissed = false;

        if (logs != null && logs.isNotEmpty) {
          // Find logs for today on this compartment that occurred within 15 minutes of scheduledDt
          LogModel? matchingLog;
          int minDiffMinutes = 999;

          for (var log in logs) {
            final isTodayLog = log.timestamp.year == now.year &&
                log.timestamp.month == now.month &&
                log.timestamp.day == now.day;

            if (isTodayLog && log.compartment == med.compartment) {
              // A log CAN ONLY match a dose if it occurred AT OR AFTER the scheduled time (or up to 1 min before)
              final bool isAtOrAfterScheduled = log.timestamp.isAfter(scheduledDt.subtract(const Duration(minutes: 1)));
              final int minsAfter = log.timestamp.difference(scheduledDt).inMinutes;

              if (isAtOrAfterScheduled && minsAfter <= 15 && minsAfter < minDiffMinutes) {
                minDiffMinutes = minsAfter;
                matchingLog = log;
              }
            }
          }

          if (matchingLog != null) {
            if (matchingLog.eventType == EventType.taken) {
              isTaken = true;
            } else if (matchingLog.eventType == EventType.missed) {
              isMissed = true;
            }
          }
        }

        if (isTaken) {
          status = 'Taken';
        } else if (isMissed) {
          status = 'Missed';
        } else if (now.isAfter(scheduledDt.add(const Duration(minutes: 15)))) {
          status = 'Missed';
        }

        items.add(DoseScheduleItem(
          medicine: med,
          time: DateFormat('HH:mm').format(scheduledDt),
          scheduledDateTime: scheduledDt,
          status: status,
        ));
      }
    }

    items.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    return items;
  }

  DoseScheduleItem? getNextPendingDose([List<LogModel>? logs]) {
    final effectiveLogs = logs ?? _latestLogs;
    final todayItems = getTodaySchedule(effectiveLogs);
    final now = DateTime.now();

    // 1. Look for upcoming doses TODAY whose time has NOT passed (or is currently active right now)
    for (var item in todayItems) {
      if (item.status == 'Pending' && item.scheduledDateTime.isAfter(now.subtract(const Duration(seconds: 45)))) {
        return item;
      }
    }

    // 2. If all today's doses are Taken/Missed/Past, pick the earliest dose scheduled for TOMORROW
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowDayShort = DateFormat('EEE').format(tomorrow);
    final tomorrowDayFull = DateFormat('EEEE').format(tomorrow);

    DoseScheduleItem? earliestTomorrowItem;

    for (var med in activeMedicines) {
      final matchesDay = med.days.any((d) =>
          d.toLowerCase() == tomorrowDayShort.toLowerCase() ||
          d.toLowerCase() == tomorrowDayFull.toLowerCase() ||
          d.toLowerCase() == 'daily');

      if (!matchesDay) continue;

      for (var t in med.times) {
        final scheduledDt = parseTimeString(t, tomorrow);
        if (scheduledDt == null) continue;

        final item = DoseScheduleItem(
          medicine: med,
          time: DateFormat('HH:mm').format(scheduledDt),
          scheduledDateTime: scheduledDt,
          status: 'Pending',
        );

        if (earliestTomorrowItem == null || scheduledDt.isBefore(earliestTomorrowItem.scheduledDateTime)) {
          earliestTomorrowItem = item;
        }
      }
    }

    if (earliestTomorrowItem != null) {
      return earliestTomorrowItem;
    }

    return null;
  }

  String getNextDoseTimeForMedicine(MedicineModel med) {
    final now = DateTime.now();
    DateTime? nextDt;

    for (var t in med.times) {
      final dt = parseTimeString(t, now);
      if (dt == null) continue;
      if (dt.isAfter(now.subtract(const Duration(seconds: 30)))) {
        if (nextDt == null || dt.isBefore(nextDt)) {
          nextDt = dt;
        }
      }
    }

    if (nextDt == null && med.times.isNotEmpty) {
      nextDt = parseTimeString(med.times.first, now);
    }

    if (nextDt != null) {
      return DateFormat('hh:mm a').format(nextDt);
    }
    return 'No time';
  }

  Future<void> syncNextDoseToDevice(String deviceId, {List<LogModel>? logs, int volume = 80, int duration = 30}) async {
    if (deviceId.isEmpty) return;

    final nextDose = getNextPendingDose(logs);
    final now = DateTime.now();

    // Check if there is a pending dose for TODAY
    final bool isTodayDose = nextDose != null &&
        nextDose.scheduledDateTime.year == now.year &&
        nextDose.scheduledDateTime.month == now.month &&
        nextDose.scheduledDateTime.day == now.day &&
        nextDose.status == 'Pending';

    if (isTodayDose && nextDose != null) {
      final formattedTime = DateFormat('HH:mm').format(nextDose.scheduledDateTime);
      await _firebaseService.updateNextDoseInDeviceState(
        deviceId,
        medicineName: nextDose.medicine.name,
        time: formattedTime,
        compartment: nextDose.medicine.compartment,
        dosage: nextDose.medicine.dosage,
        instructions: nextDose.medicine.instructions,
        hasPendingDose: true,
        buzzerVolume: volume,
        buzzerDuration: duration,
      );
    } else if (nextDose != null) {
      // Dose is for tomorrow
      final formattedTime = DateFormat('HH:mm').format(nextDose.scheduledDateTime);
      await _firebaseService.updateNextDoseInDeviceState(
        deviceId,
        medicineName: nextDose.medicine.name,
        time: formattedTime,
        compartment: nextDose.medicine.compartment,
        dosage: nextDose.medicine.dosage,
        instructions: nextDose.medicine.instructions,
        hasPendingDose: true,
        buzzerVolume: volume,
        buzzerDuration: duration,
      );
    } else {
      // No active doses scheduled
      await _firebaseService.updateNextDoseInDeviceState(
        deviceId,
        medicineName: '',
        time: '',
        compartment: 0,
        dosage: '',
        instructions: '',
        hasPendingDose: false,
        buzzerVolume: volume,
        buzzerDuration: duration,
      );
    }
  }

  @override
  void dispose() {
    _medSub?.cancel();
    _scheduleSyncTimer?.cancel();
    super.dispose();
  }
}
