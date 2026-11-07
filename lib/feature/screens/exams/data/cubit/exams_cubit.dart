import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/cubit/exams_state.dart';
import 'package:codingacademy_admin/feature/screens/exams/data/service/exams_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExamsCubit extends Cubit<ExamsState> {
  ExamsCubit({ExamsService? service})
    : _service = service ?? ExamsService(),
      super(const ExamsState()) {
    _subscriptions
      ..add(
        _service.watchExams().listen(
          (snapshot) {
            _exams = snapshot.docs;
            _examsLoaded = true;
            _examsError = null;
            _emitData();
          },
          onError: (Object error) =>
              _emitError('تعذر تحميل الامتحانات', error, isExams: true),
        ),
      )
      ..add(
        _service.watchCourses().listen(
          (snapshot) {
            _courses = snapshot.docs;
            _coursesLoaded = true;
            _coursesError = null;
            _emitData();
          },
          onError: (Object error) =>
              _emitError('تعذر تحميل الكورسات', error, isExams: false),
        ),
      );
  }

  final ExamsService _service;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _exams = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  bool _examsLoaded = false;
  bool _coursesLoaded = false;
  String? _examsError;
  String? _coursesError;

  void _emitData() {
    if (isClosed) return;
    emit(
      state.copyWith(
        exams: _exams,
        courses: _courses,
        loading:
            !(_examsLoaded && _coursesLoaded) &&
            _examsError == null &&
            _coursesError == null,
        errorMessage: _examsError ?? _coursesError,
        clearError: _examsError == null && _coursesError == null,
      ),
    );
  }

  void _emitError(String label, Object error, {required bool isExams}) {
    if (isClosed) return;
    final message = '$label: $error';
    if (isExams) {
      _examsError = message;
    } else {
      _coursesError = message;
    }
    emit(state.copyWith(loading: false, errorMessage: message));
  }

  Future<void> deleteExam(
    DocumentReference<Map<String, dynamic>> examReference,
  ) async {
    try {
      await _service.deleteExam(examReference);
    } on FirebaseException catch (error) {
      emit(
        state.copyWith(
          errorMessage: 'تعذر حذف الامتحان: ${error.message}',
          clearNotification: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          errorMessage: 'تعذر حذف الامتحان: $error',
          clearNotification: true,
        ),
      );
    }
  }

  Future<void> migrateLegacyAnswers() async {
    if (state.migrating) return;
    emit(
      state.copyWith(
        migrating: true,
        clearError: true,
        clearNotification: true,
      ),
    );
    try {
      final result = await _service.migrateLegacyAnswers();
      final unresolved = result.unresolvedQuestions;
      final message = unresolved.isEmpty
          ? 'تم تأمين إجابات ${result.migratedQuestions} سؤال'
          : 'تم تأمين ${result.migratedQuestions} سؤال، وتعذر تأمين '
                '${unresolved.length} سؤال. أصلحي: '
                '${unresolved.take(3).join('؛ ')}'
                '${unresolved.length > 3 ? '؛ والمزيد' : ''}';
      emit(state.copyWith(migrating: false, notification: message));
    } on FirebaseException catch (error) {
      emit(
        state.copyWith(
          migrating: false,
          errorMessage: error.code == 'permission-denied'
              ? 'لا يملك حساب الإدارة صلاحية تأمين الإجابات. تحققي من وجوده في '
                    'admins/{uid} ونشر قواعد Firestore.'
              : 'تعذر تأمين الامتحانات: ${error.message}',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          migrating: false,
          errorMessage: 'تعذر تأمين الامتحانات: $error',
        ),
      );
    }
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearNotification: true));
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
