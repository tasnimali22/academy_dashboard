import 'package:codingacademy_admin/feature/screens/attendance/data/cubit/attendance_report_state.dart';
import 'package:codingacademy_admin/feature/screens/attendance/data/service/attendance_report_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttendanceReportCubit extends Cubit<AttendanceReportState> {
  AttendanceReportCubit({AttendanceReportService? service})
    : _service = service ?? AttendanceReportService(),
      super(const AttendanceReportState()) {
    load();
  }

  final AttendanceReportService _service;

  Future<void> load() async {
    emit(
      state.copyWith(loading: true, clearError: true, clearNotification: true),
    );
    try {
      final report = await _service.loadReport();
      if (isClosed) return;
      emit(state.copyWith(report: report, loading: false, clearError: true));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, errorMessage: '$error'));
    }
  }

  Future<void> syncPastAttendance() async {
    if (state.syncing) return;
    emit(
      state.copyWith(syncing: true, clearError: true, clearNotification: true),
    );
    try {
      await _service.syncPastAttendance();
      final report = await _service.loadReport();
      if (isClosed) return;
      emit(
        state.copyWith(
          report: report,
          syncing: false,
          clearError: true,
          notification: 'تم تجهيز سجلات الحضور السابقة للطلاب',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          syncing: false,
          errorMessage: 'تعذرت مزامنة سجلات الحضور: $error',
        ),
      );
    }
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearNotification: true));
  }
}
