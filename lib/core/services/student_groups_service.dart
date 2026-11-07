import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/services/admin_access_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentGroupsService {
  static const legacyResourceOwnerId = 'legacy';

  static final _firestore = FirebaseFirestore.instance;

  static String get _adminId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('سجلي الدخول أولاً.');
    return uid;
  }

  static CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('admins').doc(_adminId).collection('studentGroups');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchStudents() =>
      _firestore.collection('users').snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchGroups() =>
      _groups.orderBy('createdAt', descending: true).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchCourses() =>
      AdminAccessService.watchContent('courses');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchExams() =>
      AdminAccessService.watchContent('exams');

  static Future<void> saveGroup({
    String? groupId,
    required String name,
    required Set<String> memberIds,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || memberIds.isEmpty) {
      throw ArgumentError(
        'اكتبي اسم المجموعة واختاري طالبًا واحدًا على الأقل.',
      );
    }
    if (memberIds.length > 500) {
      throw ArgumentError('لا يمكن أن تضم المجموعة أكثر من 500 طالب.');
    }
    final reference = groupId == null ? _groups.doc() : _groups.doc(groupId);
    await reference.set({
      'name': normalizedName,
      'memberIds': memberIds.toList(),
      'createdBy': _adminId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (groupId == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteGroup(String groupId) =>
      _groups.doc(groupId).delete();

  static Future<void> grantCourse(
    Set<String> memberIds,
    String courseId,
    String ownerId,
  ) async {
    await _grant(memberIds, 'adminCourseGrants', courseId, ownerId);
  }

  static Future<void> grantExam(
    Set<String> memberIds,
    String examId,
    String ownerId,
  ) async {
    await _grant(memberIds, 'adminExamGrants', examId, ownerId);
  }

  static Future<void> _grant(
    Set<String> memberIds,
    String field,
    String resourceId,
    String ownerId,
  ) async {
    if (memberIds.isEmpty) {
      throw ArgumentError('اختاري طالبًا واحدًا على الأقل.');
    }
    if (memberIds.length > 500) {
      throw ArgumentError('لا يمكن منح الصلاحية لأكثر من 500 طالب مرة واحدة.');
    }
    final normalizedOwnerId = ownerId.trim().isEmpty
        ? legacyResourceOwnerId
        : ownerId.trim();
    final ids = memberIds.toList();
    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.skip(start).take(400).toList();
      final references = chunk
          .map((id) => _firestore.collection('users').doc(id))
          .toList();
      final snapshots = await Future.wait(references.map((ref) => ref.get()));
      final batch = _firestore.batch();
      for (var index = 0; index < references.length; index++) {
        final grants = Map<String, dynamic>.from(
          snapshots[index].data()?[field] as Map? ?? const {},
        );
        final existing = (grants[normalizedOwnerId] as List? ?? const [])
            .whereType<String>()
            .toSet();
        existing.add(resourceId);
        grants[normalizedOwnerId] = existing.toList();
        batch.update(references[index], {field: grants});
      }
      await batch.commit();
    }
  }

  static Future<void> createGroupAppointment({
    required Set<String> memberIds,
    required String courseId,
    required String courseTitle,
    required String title,
    required String description,
    required DateTime startsAt,
  }) {
    if (memberIds.isEmpty) {
      throw ArgumentError('اختاري طالبًا واحدًا على الأقل.');
    }
    if (memberIds.length > 500) {
      throw ArgumentError('لا يمكن إرسال موعد لأكثر من 500 طالب مرة واحدة.');
    }
    return _firestore.collection('appointments').add({
      'title': title.trim(),
      'description': description.trim(),
      'courseId': courseId,
      'courseTitle': courseTitle,
      'startsAt': Timestamp.fromDate(startsAt),
      'targetUserIds': memberIds.toList(),
      'createdBy': _adminId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
