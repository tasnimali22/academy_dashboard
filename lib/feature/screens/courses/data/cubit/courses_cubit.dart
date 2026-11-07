import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/feature/screens/courses/data/cubit/courses_state.dart';
import 'package:codingacademy_admin/feature/screens/courses/data/model/courses_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CoursesCubit extends Cubit<CoursesState> {
  CoursesCubit() : super(const CoursesState()) {
    _sub = _db.collection('courses').orderBy('order').snapshots().listen(
      (snap) {
        final list = snap.docs.map((d) {
          final data = d.data();
          return CourseModel(
            d.id,
            (data['title'] ?? d.id) as String,
            (data['order'] ?? 0) as int,
          );
        }).toList();
        if (!isClosed) emit(CoursesState(loading: false, courses: list));
      },
      onError: (e) {
        print('🔴 $e');
        if (!isClosed) {
          emit(const CoursesState(
              loading: false, message: 'تعذر تحميل الكورسات'));
        }
      },
    );
  }

  final _db = FirebaseFirestore.instance;
  final titleController = TextEditingController();
  final idController = TextEditingController();
  StreamSubscription? _sub;

  void _say(String m) =>
      emit(CoursesState(loading: false, courses: state.courses, message: m));

  Future<bool> addCourse() async {
    final id = idController.text.trim().toLowerCase();
    final title = titleController.text.trim();

    if (title.isEmpty) {
      _say('اكتبي اسم الكورس');
      return false;
    }
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(id)) {
      _say('الرمز: حروف إنجليزية صغيرة وأرقام فقط');
      return false;
    }

    try {
      final ref = _db.collection('courses').doc(id);
      if ((await ref.get()).exists) {
        _say('الرمز مستخدم بالفعل');
        return false;
      }
      final maxOrder = state.courses.isEmpty
          ? 0
          : state.courses.map((c) => c.order).reduce((a, b) => a > b ? a : b);

      await ref.set({
        'title': title,
        'order': maxOrder + 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
      titleController.clear();
      idController.clear();
      return true;
    } catch (e) {
      print('🔴 $e');
      _say('تعذر إضافة الكورس');
      return false;
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      final ref = _db.collection('courses').doc(id);
      final lessons = await ref.collection('lessons').get();

      for (var i = 0; i < lessons.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in lessons.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await ref.delete();
    } catch (e) {
      print('🔴 $e');
      _say('تعذر حذف الكورس');
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    titleController.dispose();
    idController.dispose();
    return super.close();
  }
}