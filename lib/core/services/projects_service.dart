import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/core/services/admin_access_service.dart';

class ProjectsService {
  static final _firestore = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchProjects() async* {
    final uid = await AdminAccessService.requireUserId();
    final isSuperAdmin = await AdminAccessService.isSuperAdmin();
    Query<Map<String, dynamic>> query = _firestore.collection('projects');
    if (!isSuperAdmin) {
      query = query.where('createdBy', isEqualTo: uid);
    }
    yield* query.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchSubmissions(
    String projectId,
  ) => _firestore
      .collection('projects')
      .doc(projectId)
      .collection('submissions')
      .snapshots();

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  loadStudents() async {
    final snapshots = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('admins').get(),
    ]);
    final adminIds = snapshots[1].docs.map((admin) => admin.id).toSet();
    return snapshots[0].docs
        .where((student) => !adminIds.contains(student.id))
        .toList();
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  loadCurrentAdminGroups() async {
    final uid = await AdminAccessService.requireUserId();
    final snapshot = await _firestore
        .collection('admins')
        .doc(uid)
        .collection('studentGroups')
        .get();
    return snapshot.docs;
  }

  static Future<void> createProject({
    required String title,
    required String description,
    required String attachmentUrl,
    required Set<String> studentIds,
    required Set<String> groupIds,
    DateTime? dueAt,
  }) async {
    if (studentIds.isEmpty || studentIds.length > 500) {
      throw ArgumentError('اختاري من طالب إلى 500 طالب للمشروع.');
    }
    if (groupIds.length > 500) {
      throw ArgumentError('لا يمكن ربط أكثر من 500 مجموعة بالمشروع.');
    }
    final uid = await AdminAccessService.requireUserId();
    await _firestore.collection('projects').add({
      'title': title.trim(),
      'description': description.trim(),
      'attachmentUrl': attachmentUrl.trim(),
      'targetUserIds': studentIds.toList(),
      'targetGroupIds': groupIds.toList(),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'published': true,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateProject({
    required String projectId,
    required String title,
    required String description,
    required String attachmentUrl,
    required Set<String> studentIds,
    required Set<String> groupIds,
    DateTime? dueAt,
  }) async {
    if (studentIds.isEmpty || studentIds.length > 500) {
      throw ArgumentError('اختاري من طالب إلى 500 طالب للمشروع.');
    }
    if (groupIds.length > 500) {
      throw ArgumentError('لا يمكن ربط أكثر من 500 مجموعة بالمشروع.');
    }
    await _firestore.collection('projects').doc(projectId).update({
      'title': title.trim(),
      'description': description.trim(),
      'attachmentUrl': attachmentUrl.trim(),
      'targetUserIds': studentIds.toList(),
      'targetGroupIds': groupIds.toList(),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateProjectAccess({
    required String projectId,
    required Set<String> studentIds,
    required Set<String> groupIds,
  }) async {
    if (studentIds.isEmpty || studentIds.length > 500) {
      throw ArgumentError('اختاري من طالب إلى 500 طالب للمشروع.');
    }
    if (groupIds.length > 500) {
      throw ArgumentError('لا يمكن ربط أكثر من 500 مجموعة بالمشروع.');
    }
    await _firestore.collection('projects').doc(projectId).update({
      'targetUserIds': studentIds.toList(),
      'targetGroupIds': groupIds.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteProject(String projectId) async {
    final project = _firestore.collection('projects').doc(projectId);
    final submissions = project.collection('submissions');
    while (true) {
      final page = await submissions.limit(400).get();
      if (page.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final submission in page.docs) {
        batch.delete(submission.reference);
      }
      await batch.commit();
    }
    await project.delete();
  }

  static Future<void> gradeSubmission({
    required String projectId,
    required String studentId,
    required int grade,
    required String feedback,
  }) async {
    if (grade < 0 || grade > 100) {
      throw ArgumentError.value(
        grade,
        'grade',
        'التقييم يجب أن يكون من 0 إلى 100',
      );
    }
    final uid = await AdminAccessService.requireUserId();
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('submissions')
        .doc(studentId)
        .update({
          'grade': grade,
          'feedback': feedback.trim(),
          'gradedAt': FieldValue.serverTimestamp(),
          'gradedBy': uid,
        });
  }
}
