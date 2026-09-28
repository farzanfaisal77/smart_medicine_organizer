import 'dart:async';
import 'package:flutter/material.dart';
import '../models/log_model.dart';
import '../services/firebase_service.dart';

class LogProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  List<LogModel> _logs = [];
  bool _isLoading = false;
  int? _compartmentFilter;
  EventType? _eventTypeFilter;
  StreamSubscription<List<LogModel>>? _logSub;

  LogProvider(this._firebaseService);

  List<LogModel> get logs => _logs;
  bool get isLoading => _isLoading;
  int? get compartmentFilter => _compartmentFilter;
  EventType? get eventTypeFilter => _eventTypeFilter;

  List<LogModel> get filteredLogs {
    return _logs.where((log) {
      if (_compartmentFilter != null && log.compartment != _compartmentFilter) {
        return false;
      }
      if (_eventTypeFilter != null && log.eventType != _eventTypeFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  void setCompartmentFilter(int? compartment) {
    _compartmentFilter = compartment;
    notifyListeners();
  }

  void setEventTypeFilter(EventType? type) {
    _eventTypeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _compartmentFilter = null;
    _eventTypeFilter = null;
    notifyListeners();
  }

  void listenToLogs(String uid, {Function(List<LogModel>)? onLogsUpdated}) {
    _logSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _logSub = _firebaseService.streamLogs(uid).listen((list) {
      _logs = list;
      _isLoading = false;
      notifyListeners();
      if (onLogsUpdated != null) {
        onLogsUpdated(list);
      }
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  void stopListening() {
    _logSub?.cancel();
    _logs = [];
    notifyListeners();
  }

  Future<void> addLog(String uid, LogModel log) async {
    await _firebaseService.addLog(uid, log);
  }

  @override
  void dispose() {
    _logSub?.cancel();
    super.dispose();
  }
}
