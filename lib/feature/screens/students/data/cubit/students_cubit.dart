import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:codingacademy_admin/core/services/admin_access_service.dart';
import 'package:codingacademy_admin/core/services/student_accounts_service.dart';
import 'package:codingacademy_admin/feature/screens/students/data/cubit/students_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StudentsCubit extends Cubit<StudentsState> {
  StudentsCubit() : super(const StudentsState()) {
    _loadCurrentRole();
    _subscriptions
      ..add(
        StudentAccountsService.watchAdmins().listen(
          (snapshot) {
            _adminIds = snapshot.docs.map((document) => document.id).toSet();
            _adminRoles = {
              for (final document in snapshot.docs)
                document.id: document.data()['role'] as String? ?? 'admin',
            };
            _superAdminIds = _adminRoles.entries
                .where((entry) => entry.value == 'superAdmin')
                .map((entry) => entry.key)
                .toSet();
            _includeBootstrapSuperAdmin();
            _adminsLoaded = true;
            _emitData();
          },
          onError: (Object error) =>
              _emitStreamError('تعذر تحميل حسابات الإدارة', error),
        ),
      )
      ..add(
        StudentAccountsService.watchStudents().listen(
          (snapshot) {
            _students = snapshot.docs;
            _studentsLoaded = true;
            _emitData();
          },
          onError: (Object error) =>
              _emitStreamError('تعذر تحميل الطلاب', error),
        ),
      )
      ..add(
        StudentAccountsService.watchCourses().listen(
          (snapshot) {
            _courses = snapshot.docs;
            _coursesLoaded = true;
            _emitData();
          },
          onError: (Object error) =>
              _emitStreamError('تعذر تحميل الكورسات', error),
        ),
      )
      ..add(
        StudentAccountsService.watchExams().listen(
          (snapshot) {
            _exams = snapshot.docs;
            _examsLoaded = true;
            _emitData();
          },
          onError: (Object error) =>
              _emitStreamError('تعذر تحميل الامتحانات', error),
        ),
      );
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _students = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _exams = [];
  Set<String> _adminIds = {};
  Map<String, String> _adminRoles = {};
  Set<String> _superAdminIds = {};
  bool _isSuperAdmin = false;
  bool _adminsLoaded = false;
  bool _studentsLoaded = false;
  bool _coursesLoaded = false;
  bool _examsLoaded = false;

  void _emitData() {
    if (isClosed) return;
    emit(
      state.copyWith(
        students: _students,
        courses: _courses,
        exams: _exams,
        adminIds: _adminIds,
        adminRoles: _adminRoles,
        superAdminIds: _superAdminIds,
        isSuperAdmin: _isSuperAdmin,
        loading:
            !(_adminsLoaded &&
                _studentsLoaded &&
                _coursesLoaded &&
                _examsLoaded),
        clearError: true,
      ),
    );
  }

  Future<void> _loadCurrentRole() async {
    try {
      _isSuperAdmin =
          await AdminAccessService.currentRole() == DashboardRole.superAdmin;
      _includeBootstrapSuperAdmin();
      _emitData();
    } catch (error) {
      _emitStreamError('تعذر التحقق من صلاحيات الحساب', error);
    }
  }

  void _includeBootstrapSuperAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isSuperAdmin ||
        user?.email?.toLowerCase() != AdminAccessService.superAdminEmail) {
      return;
    }
    _adminIds.add(user!.uid);
    _adminRoles[user.uid] = 'superAdmin';
    _superAdminIds.add(user.uid);
  }

  void _emitStreamError(String label, Object error) {
    if (isClosed) return;
    emit(state.copyWith(loading: false, errorMessage: '$label: $error'));
  }

  Future<void> refresh() async {
    if (state.refreshing) return;
    emit(state.copyWith(refreshing: true, clearNotification: true));
    try {
      final result = await StudentAccountsService.refresh();
      _adminIds = result.adminIds;
      _adminRoles = result.adminRoles;
      _superAdminIds = _adminRoles.entries
          .where((entry) => entry.value == 'superAdmin')
          .map((entry) => entry.key)
          .toSet();
      _students = result.students;
      _includeBootstrapSuperAdmin();
      _adminsLoaded = true;
      _studentsLoaded = true;
      emit(
        state.copyWith(
          students: _students,
          adminIds: _adminIds,
          adminRoles: _adminRoles,
          superAdminIds: _superAdminIds,
          loading: !(_coursesLoaded && _examsLoaded),
          refreshing: false,
          notification: 'تم تحديث قائمة الطلاب: ${result.studentCount} طالب',
          clearError: true,
        ),
      );
    } on FirebaseException catch (error) {
      emit(
        state.copyWith(
          loading: false,
          refreshing: false,
          errorMessage: 'تعذر تحديث قائمة الطلاب: ${error.message}',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loading: false,
          refreshing: false,
          errorMessage: 'تعذر تحديث قائمة الطلاب: $error',
        ),
      );
    }
  }

  Future<void> createStudentAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    if (state.creatingAccount) return;
    emit(
      state.copyWith(
        creatingAccount: true,
        clearError: true,
        clearNotification: true,
      ),
    );
    try {
      await StudentAccountsService.createStudentAccount(
        name: name,
        email: email,
        password: password,
      );
      emit(
        state.copyWith(
          creatingAccount: false,
          notification: 'تم إنشاء حساب الطالب بنجاح',
        ),
      );
    } on FirebaseAuthException catch (error) {
      emit(
        state.copyWith(
          creatingAccount: false,
          errorMessage: 'تعذر إنشاء الحساب: ${error.message ?? error.code}',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          creatingAccount: false,
          errorMessage: 'تعذر إنشاء الحساب: $error',
        ),
      );
    }
  }

  Future<void> setAdminRole(String userId, {required String? role}) async {
    if (state.accountActionIds.contains(userId)) return;
    emit(
      state.copyWith(
        accountActionIds: {...state.accountActionIds, userId},
        clearError: true,
        clearNotification: true,
      ),
    );
    try {
      await StudentAccountsService.setAdminRole(studentId: userId, role: role);
      final accountActionIds = {...state.accountActionIds}..remove(userId);
      final adminIds = {...state.adminIds};
      final adminRoles = {...state.adminRoles};
      final superAdminIds = {...state.superAdminIds};
      if (role == null) {
        adminIds.remove(userId);
        adminRoles.remove(userId);
        superAdminIds.remove(userId);
      } else {
        adminIds.add(userId);
        adminRoles[userId] = role;
        if (role == 'superAdmin') {
          superAdminIds.add(userId);
        } else {
          superAdminIds.remove(userId);
        }
      }
      emit(
        state.copyWith(
          adminIds: adminIds,
          adminRoles: adminRoles,
          superAdminIds: superAdminIds,
          accountActionIds: accountActionIds,
          notification: switch (role) {
            'superAdmin' => 'تم تعيين الحساب Super Admin',
            'admin' => 'تم تعيين الحساب Admin',
            _ => 'تمت إزالة صلاحية الأدمن',
          },
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      final accountActionIds = {...state.accountActionIds}..remove(userId);
      emit(
        state.copyWith(
          accountActionIds: accountActionIds,
          errorMessage: 'تعذر تعديل صلاحية الأدمن: ${error.message}',
        ),
      );
    } catch (error) {
      final accountActionIds = {...state.accountActionIds}..remove(userId);
      emit(
        state.copyWith(
          accountActionIds: accountActionIds,
          errorMessage: 'تعذر تعديل صلاحية الأدمن: $error',
        ),
      );
    }
  }

  Future<void> deleteAccount(String userId) async {
    if (state.accountActionIds.contains(userId)) return;
    emit(
      state.copyWith(
        accountActionIds: {...state.accountActionIds, userId},
        clearError: true,
        clearNotification: true,
      ),
    );
    try {
      await StudentAccountsService.deleteAccount(userId);
      final accountActionIds = {...state.accountActionIds}..remove(userId);
      final adminIds = {...state.adminIds}..remove(userId);
      final adminRoles = {...state.adminRoles}..remove(userId);
      final superAdminIds = {...state.superAdminIds}..remove(userId);
      final students = state.students
          .where((student) => student.id != userId)
          .toList();
      emit(
        state.copyWith(
          students: students,
          adminIds: adminIds,
          adminRoles: adminRoles,
          superAdminIds: superAdminIds,
          accountActionIds: accountActionIds,
          notification: 'تم حذف الحساب نهائيًا',
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      final accountActionIds = {...state.accountActionIds}..remove(userId);
      emit(
        state.copyWith(
          accountActionIds: accountActionIds,
          errorMessage: error.code == 'not-found'
              ? 'دالة حذف الحساب غير منشورة على Firebase. حذف الحساب بالكامل '
                    'يحتاج تفعيل خطة Blaze ثم نشر Cloud Functions.'
              : 'تعذر حذف الحساب: ${error.message ?? error.code}',
        ),
      );
    } catch (error) {
      final accountActionIds = {...state.accountActionIds}..remove(userId);
      emit(
        state.copyWith(
          accountActionIds: accountActionIds,
          errorMessage: 'تعذر حذف الحساب: $error',
        ),
      );
    }
  }

  void clearNotification() {
    emit(state.copyWith(clearNotification: true));
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
