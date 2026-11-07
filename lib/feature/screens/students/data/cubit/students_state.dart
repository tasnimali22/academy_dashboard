import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class StudentsState extends Equatable {
  const StudentsState({
    this.students = const [],
    this.courses = const [],
    this.exams = const [],
    this.adminIds = const {},
    this.adminRoles = const {},
    this.superAdminIds = const {},
    this.isSuperAdmin = false,
    this.loading = true,
    this.refreshing = false,
    this.accountActionIds = const {},
    this.creatingAccount = false,
    this.errorMessage,
    this.notification,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> courses;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> exams;
  final Set<String> adminIds;
  final Map<String, String> adminRoles;
  final Set<String> superAdminIds;
  final bool isSuperAdmin;
  final bool loading;
  final bool refreshing;
  final Set<String> accountActionIds;
  final bool creatingAccount;
  final String? errorMessage;
  final String? notification;

  StudentsState copyWith({
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? students,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? courses,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? exams,
    Set<String>? adminIds,
    Map<String, String>? adminRoles,
    Set<String>? superAdminIds,
    bool? isSuperAdmin,
    bool? loading,
    bool? refreshing,
    Set<String>? accountActionIds,
    bool? creatingAccount,
    String? errorMessage,
    bool clearError = false,
    String? notification,
    bool clearNotification = false,
  }) {
    return StudentsState(
      students: students ?? this.students,
      courses: courses ?? this.courses,
      exams: exams ?? this.exams,
      adminIds: adminIds ?? this.adminIds,
      adminRoles: adminRoles ?? this.adminRoles,
      superAdminIds: superAdminIds ?? this.superAdminIds,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      accountActionIds: accountActionIds ?? this.accountActionIds,
      creatingAccount: creatingAccount ?? this.creatingAccount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      notification: clearNotification
          ? null
          : notification ?? this.notification,
    );
  }

  @override
  List<Object?> get props => [
    students,
    courses,
    exams,
    adminIds,
    adminRoles,
    superAdminIds,
    isSuperAdmin,
    loading,
    refreshing,
    accountActionIds,
    creatingAccount,
    errorMessage,
    notification,
  ];
}
