import 'package:cloud_firestore/cloud_firestore.dart';

class CompartmentStatus {
  final int id;
  final bool isOpen;
  final bool ledOn;
  final String ledColor; // 'OFF', 'GREEN', 'RED', 'BLUE', 'PURPLE', 'PINK', 'WHITE', 'YELLOW', 'CYAN', 'ORANGE'

  CompartmentStatus({
    required this.id,
    required this.isOpen,
    required this.ledOn,
    this.ledColor = 'OFF',
  });

  factory CompartmentStatus.fromMap(Map<String, dynamic> map, [int defaultId = 1]) {
    String color = (map['ledColor'] ?? 'OFF').toString().toUpperCase();
    bool ledOn = map['ledOn'] ?? (color != 'OFF');
    return CompartmentStatus(
      id: (map['id'] ?? defaultId) as int,
      isOpen: map['isOpen'] ?? false,
      ledOn: ledOn,
      ledColor: color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isOpen': isOpen,
      'ledOn': ledOn || ledColor != 'OFF',
      'ledColor': ledColor,
    };
  }
}

class DeviceStateModel {
  final String deviceId;
  final bool isOnline;
  final int batteryLevel;
  final DateTime lastSeen;
  final List<CompartmentStatus> compartmentStatus;
  final String lastEvent;
  final String lastEventDetails;
  final int lastEventCompartment;

  DeviceStateModel({
    required this.deviceId,
    required this.isOnline,
    required this.batteryLevel,
    required this.lastSeen,
    required this.compartmentStatus,
    this.lastEvent = '',
    this.lastEventDetails = '',
    this.lastEventCompartment = 0,
  });

  factory DeviceStateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawIsOnline = data['isOnline'] ?? false;
    
    DateTime lastSeenDt = DateTime.fromMillisecondsSinceEpoch(0);
    if (data['lastSeen'] is Timestamp) {
      lastSeenDt = (data['lastSeen'] as Timestamp).toDate();
    }

    final int secondsSinceLastSeen = DateTime.now().difference(lastSeenDt).inSeconds.abs();
    final bool neverUpdatedByDevice = lastSeenDt.millisecondsSinceEpoch <= 1000;
    final bool realIsOnline = rawIsOnline && (secondsSinceLastSeen < 30 || data['lastSeen'] == null || neverUpdatedByDevice);

    List<CompartmentStatus> statusList = [];
    if (data['compartmentStatus'] is List) {
      final rawList = data['compartmentStatus'] as List<dynamic>;
      for (int i = 0; i < 6; i++) {
        final fieldColor = (data['c${i + 1}Color'] ?? 'OFF').toString().toUpperCase();
        bool isOpen = (data['c${i + 1}Open'] == true);
        if (i < rawList.length && rawList[i] is Map) {
          final map = Map<String, dynamic>.from(rawList[i]);
          if (map['isOpen'] != null) isOpen = map['isOpen'] == true;
          final mapColor = (map['ledColor'] ?? fieldColor).toString().toUpperCase();
          statusList.add(CompartmentStatus(
            id: i + 1,
            isOpen: isOpen,
            ledOn: mapColor != 'OFF',
            ledColor: mapColor,
          ));
        } else {
          statusList.add(CompartmentStatus(
            id: i + 1,
            isOpen: isOpen,
            ledOn: fieldColor != 'OFF',
            ledColor: fieldColor,
          ));
        }
      }
    } else {
      statusList = List.generate(
        6,
        (index) {
          final fieldColor = (data['c${index + 1}Color'] ?? 'OFF').toString().toUpperCase();
          final bool isOpen = (data['c${index + 1}Open'] == true);
          return CompartmentStatus(
            id: index + 1,
            isOpen: isOpen,
            ledOn: fieldColor != 'OFF',
            ledColor: fieldColor,
          );
        },
      );
    }

    return DeviceStateModel(
      deviceId: doc.id,
      isOnline: realIsOnline,
      batteryLevel: (data['batteryLevel'] ?? 0) as int,
      lastSeen: lastSeenDt,
      compartmentStatus: statusList,
      lastEvent: data['lastEvent'] ?? '',
      lastEventDetails: data['lastEventDetails'] ?? '',
      lastEventCompartment: (data['lastEventCompartment'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'isOnline': isOnline,
      'batteryLevel': batteryLevel,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'compartmentStatus': compartmentStatus.map((e) => e.toMap()).toList(),
      'lastEvent': lastEvent,
      'lastEventDetails': lastEventDetails,
      'lastEventCompartment': lastEventCompartment,
    };
    for (var c in compartmentStatus) {
      map['c${c.id}Color'] = c.ledColor;
    }
    return map;
  }

  static DeviceStateModel initial(String deviceId) {
    return DeviceStateModel(
      deviceId: deviceId,
      isOnline: false,
      batteryLevel: 0,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
      compartmentStatus: List.generate(
        6,
        (i) => CompartmentStatus(id: i + 1, isOpen: false, ledOn: false, ledColor: 'OFF'),
      ),
    );
  }
}
