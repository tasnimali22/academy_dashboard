import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/utils/youtube_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LessonItem {
  final String id;
  final String title;
  final String videoId;
  final int order;
  const LessonItem(this.id, this.title, this.videoId, this.order);
}

class LessonsState {
  final bool loading;
  final List<LessonItem> lessons;
  final String? message;
  const LessonsState({
    this.loading = true,
    this.lessons = const [],
    this.message,
  });
}

class LessonsCubit extends Cubit<LessonsState> {
  LessonsCubit(this.courseId) : super(const LessonsState()) {
    _sub = _col.orderBy('order').snapshots().listen(
      (snap) {
        final list = snap.docs.map((d) {
          final data = d.data();
          return LessonItem(
            d.id,
            (data['title'] ?? '') as String,
            (data['videoId'] ?? '') as String,
            (data['order'] ?? 0) as int,
          );
        }).toList();
        if (!isClosed) emit(LessonsState(loading: false, lessons: list));
      },
      onError: (e) {
        print('🔴 $e');
        if (!isClosed) {
          emit(const LessonsState(
              loading: false, message: 'تعذر تحميل الفيديوهات'));
        }
      },
    );
  }

  final String courseId;
  final titleController = TextEditingController();
  final linkController = TextEditingController();
  StreamSubscription? _sub;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('courses')
      .doc(courseId)
      .collection('lessons');

  void _say(String m) =>
      emit(LessonsState(loading: false, lessons: state.lessons, message: m));

  Future<bool> addLesson() async {
    final videoId = extractYoutubeId(linkController.text);
    if (videoId == null) {
      _say('الرابط غير صحيح');
      return false;
    }

    final maxOrder = state.lessons.isEmpty
        ? 0
        : state.lessons.map((l) => l.order).reduce((a, b) => a > b ? a : b);
    final next = maxOrder + 1;

    final title = titleController.text.trim().isEmpty
        ? 'الدرس $next'
        : titleController.text.trim();

    try {
      await _col.add({
        'title': title,
        'videoId': videoId,
        'order': next,
        'createdAt': FieldValue.serverTimestamp(),
      });
      titleController.clear();
      linkController.clear();
      return true;
    } catch (e) {
      print('🔴 $e');
      _say('تعذر إضافة الفيديو');
      return false;
    }
  }

  Future<void> deleteLesson(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e) {
      print('🔴 $e');
      _say('تعذر حذف الفيديو');
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    titleController.dispose();
    linkController.dispose();
    return super.close();
  }
}