import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, justified }

extension AttendanceStatusExt on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:   return 'P';
      case AttendanceStatus.absent:    return 'F';
      case AttendanceStatus.late:      return 'R';
      case AttendanceStatus.justified: return 'J';
    }
  }

  String get fullLabel {
    switch (this) {
      case AttendanceStatus.present:   return 'Presente';
      case AttendanceStatus.absent:    return 'Falta';
      case AttendanceStatus.late:      return 'Retardo';
      case AttendanceStatus.justified: return 'Justificado';
    }
  }

  AttendanceStatus get next {
    final values = AttendanceStatus.values;
    return values[(index + 1) % values.length];
  }
}

class AttendanceModel {
  final String id;
  final String groupId;
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;

  const AttendanceModel({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.date,
    required this.status,
    this.notes,
  });

  factory AttendanceModel.fromFirestore(Map<String, dynamic> d, String id) =>
      AttendanceModel(
        id: id,
        groupId: d['groupId'] ?? '',
        studentId: d['studentId'] ?? '',
        date: (d['date'] as Timestamp).toDate(),
        status: AttendanceStatus.values.byName(d['status'] ?? 'present'),
        notes: d['notes'],
      );

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'studentId': studentId,
        'date': Timestamp.fromDate(date),
        'status': status.name,
        'notes': notes,
      };
}