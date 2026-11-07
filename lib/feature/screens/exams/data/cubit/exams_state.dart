import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ExamsState extends Equatable {
  const ExamsState({
    this.exams = const [],
    this.courses = const [],
    this.loading = true,
    this.migrating = false,
    this.errorMessage,
    this.notification,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> exams;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> courses;
  final bool loading;
  final bool migrating;
  final String? errorMessage;
  final String? notification;

  ExamsState copyWith({
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? exams,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? courses,
    bool? loading,
    bool? migrating,
    String? errorMessage,
    bool clearError = false,
    String? notification,
    bool clearNotification = false,
  }) {
    return ExamsState(
      exams: exams ?? this.exams,
      courses: courses ?? this.courses,
      loading: loading ?? this.loading,
      migrating: migrating ?? this.migrating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      notification: clearNotification
          ? null
          : notification ?? this.notification,
    );
  }

  @override
  List<Object?> get props => [
    exams,
    courses,
    loading,
    migrating,
    errorMessage,
    notification,
  ];
}
