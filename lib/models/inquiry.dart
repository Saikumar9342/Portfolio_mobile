import 'package:cloud_firestore/cloud_firestore.dart';

class Inquiry {
  final String id;
  final String name;
  final String email;
  final String? subject;
  final String message;
  final String status;
  final DateTime timestamp;

  Inquiry({
    required this.id,
    required this.name,
    required this.email,
    this.subject,
    required this.message,
    required this.status,
    required this.timestamp,
  });

  factory Inquiry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Inquiry(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      subject: data['subject'],
      message: data['message'] ?? '',
      status: data['status'] ?? 'unread',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
