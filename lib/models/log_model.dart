import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { taken, missed, wrongCompartment, unknown }

extension EventTypeExtension on EventType {
  String get rawValue {
    switch (this) {
      case EventType.taken:
        return 'TAKEN';
      case EventType.missed:
        return 'MISSED';
      case EventType.wrongCompartment:
        return 'WRONG_COMPARTMENT';
      default:
        return 'UNKNOWN';
    }
  }

  static EventType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'TAKEN':
        return EventType.taken;
      case 'MISSED':
        return EventType.missed;
      case 'WRONG_COMPARTMENT':
        return EventType.wrongCompartment;
      default:
        return EventType.unknown;
    }
  }
}

class LogModel {
  final String id;
  final int compartment;
  final DateTime timestamp;
  final EventType eventType;
  final String details;

  LogModel({
    required this.id,
    required this.compartment,
    required this.timestamp,
    required this.eventType,
    required this.details,
  });

  factory LogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LogModel(
      id: doc.id,
      compartment: (data['compartment'] ?? 0) as int,
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      eventType: EventTypeExtension.fromString(data['eventType'] ?? ''),
      details: data['details'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'compartment': compartment,
      'timestamp': Timestamp.fromDate(timestamp),
      'eventType': eventType.rawValue,
      'details': details,
    };
  }
}
