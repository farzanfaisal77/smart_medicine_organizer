import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineModel {
  final String id;
  final String name;
  final int compartment; // 1 to 6
  final String dosage;
  final String instructions;
  final List<String> times; // ["08:00", "20:00"]
  final List<String> days; // ["Mon", "Tue", "Wed", ...]
  final bool active;
  final DateTime createdAt;

  MedicineModel({
    required this.id,
    required this.name,
    required this.compartment,
    required this.dosage,
    required this.instructions,
    required this.times,
    required this.days,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MedicineModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MedicineModel(
      id: doc.id,
      name: data['name'] ?? '',
      compartment: (data['compartment'] ?? 1) as int,
      dosage: data['dosage'] ?? '',
      instructions: data['instructions'] ?? '',
      times: List<String>.from(data['times'] ?? []),
      days: List<String>.from(data['days'] ?? []),
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'compartment': compartment,
      'dosage': dosage,
      'instructions': instructions,
      'times': times,
      'days': days,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  MedicineModel copyWith({
    String? id,
    String? name,
    int? compartment,
    String? dosage,
    String? instructions,
    List<String>? times,
    List<String>? days,
    bool? active,
    DateTime? createdAt,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      compartment: compartment ?? this.compartment,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      times: times ?? this.times,
      days: days ?? this.days,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
