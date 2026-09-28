class UserModel {
  final String uid;
  final String email;
  final String name;
  final String deviceId;
  final bool pushNotificationsEnabled;
  final bool smsNotificationsEnabled;
  final int buzzerVolume;
  final int buzzerDuration;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.deviceId,
    this.pushNotificationsEnabled = true,
    this.smsNotificationsEnabled = false,
    this.buzzerVolume = 80,
    this.buzzerDuration = 30,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      deviceId: map['deviceId'] ?? '',
      pushNotificationsEnabled: map['pushNotificationsEnabled'] ?? true,
      smsNotificationsEnabled: map['smsNotificationsEnabled'] ?? false,
      buzzerVolume: (map['buzzerVolume'] ?? 80) as int,
      buzzerDuration: (map['buzzerDuration'] ?? 30) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'deviceId': deviceId,
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'smsNotificationsEnabled': smsNotificationsEnabled,
      'buzzerVolume': buzzerVolume,
      'buzzerDuration': buzzerDuration,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? deviceId,
    bool? pushNotificationsEnabled,
    bool? smsNotificationsEnabled,
    int? buzzerVolume,
    int? buzzerDuration,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      smsNotificationsEnabled: smsNotificationsEnabled ?? this.smsNotificationsEnabled,
      buzzerVolume: buzzerVolume ?? this.buzzerVolume,
      buzzerDuration: buzzerDuration ?? this.buzzerDuration,
    );
  }
}
