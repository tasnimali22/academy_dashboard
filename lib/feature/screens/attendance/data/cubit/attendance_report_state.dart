import 'package:codingacademy_admin/feature/screens/attendance/data/model/student_attendance_report.dart';
import 'package:equatable/equatable.dart';

class AttendanceReportState extends Equatable {
  const AttendanceReportState({
    this.report,
    this.loading = true,
    this.syncing = false,
    this.errorMessage,
    this.notification,
  });

  final AttendanceReport? report;
  final bool loading;
  final bool syncing;
  final String? errorMessage;
  final String? notification;

  AttendanceReportState copyWith({
    AttendanceReport? report,
    bool? loading,
    bool? syncing,
    String? errorMessage,
    bool clearError = false,
    String? notification,
    bool clearNotification = false,
  }) {
    return AttendanceReportState(
      report: report ?? this.report,
      loading: loading ?? this.loading,
      syncing: syncing ?? this.syncing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      notification: clearNotification
          ? null
          : notification ?? this.notification,
    );
  }

  @override
  List<Object?> get props => [
    report,
    loading,
    syncing,
    errorMessage,
    notification,
  ];
}
