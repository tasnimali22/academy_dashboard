import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/services/student_accounts_service.dart';
import 'package:codingacademy_admin/feature/screens/students/data/cubit/student_permissions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StudentPermissionsCubit extends Cubit<StudentPermissionsState> {
  StudentPermissionsCubit({
    required this.student,
    required Set<String> courseIds,
    required Set<String> examIds,
  }) : super(
         StudentPermissionsState(
           courseIds: Set.unmodifiable(courseIds),
           examIds: Set.unmodifiable(examIds),
         ),
       );

  final DocumentReference<Map<String, dynamic>> student;

  void toggleCourse(String id, bool enabled) {
    final courseIds = Set<String>.of(state.courseIds);
    enabled ? courseIds.add(id) : courseIds.remove(id);
    emit(
      state.copyWith(
        courseIds: Set.unmodifiable(courseIds),
        saved: false,
        clearError: true,
      ),
    );
  }

  void toggleExam(String id, bool enabled) {
    final examIds = Set<String>.of(state.examIds);
    enabled ? examIds.add(id) : examIds.remove(id);
    emit(
      state.copyWith(
        examIds: Set.unmodifiable(examIds),
        saved: false,
        clearError: true,
      ),
    );
  }

  Future<void> save() async {
    if (state.saving) return;
    emit(state.copyWith(saving: true, saved: false, clearError: true));
    try {
      await StudentAccountsService.savePermissions(
        student: student,
        courseIds: state.courseIds,
        examIds: state.examIds,
      );
      emit(state.copyWith(saving: false, saved: true));
    } on FirebaseException catch (error) {
      final message = error.code == 'permission-denied'
          ? 'رفضت قواعد Firestore حفظ الصلاحيات. تأكدي من نشر firestore.rules '
                'ومن تسجيل حساب الإدارة الحالي في admins/{uid}.'
          : 'تعذر حفظ الصلاحيات: ${error.message}';
      emit(state.copyWith(saving: false, errorMessage: message));
    } catch (error) {
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'تعذر حفظ الصلاحيات: $error',
        ),
      );
    }
  }
}
