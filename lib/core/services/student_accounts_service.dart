import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:codingacademy_admin/core/services/admin_access_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:codingacademy_admin/firebase_options.dart';

class StudentAccountsRefreshResult {
  const StudentAccountsRefreshResult({
    required this.adminIds,
    required this.adminRoles,
    required this.students,
    required this.studentCount,
  });

  final Set<String> adminIds;
  final Map<String, String> adminRoles;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;
  final int studentCount;
}

class StudentAccountsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchAdmins() =>
      _firestore.collection('admins').snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchStudents() =>
      _firestore.collection('users').snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchCourses() =>
      AdminAccessService.watchContent('courses');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchExams() =>
      AdminAccessService.watchContent('exams');

  static Future<Set<String>> loadAdminIds() async {
    final snapshot = await _firestore.collection('admins').get();
    return snapshot.docs.map((document) => document.id).toSet();
  }

  static Future<StudentAccountsRefreshResult> refresh() async {
    final snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      _firestore
          .collection('admins')
          .get(const GetOptions(source: Source.server)),
      _firestore
          .collection('users')
          .get(const GetOptions(source: Source.server)),
    ]);

    final adminIds = snapshots[0].docs.map((document) => document.id).toSet();
    final adminRoles = {
      for (final document in snapshots[0].docs)
        document.id: document.data()['role'] as String? ?? 'admin',
    };
    final studentCount = snapshots[1].docs
        .where((document) => !adminIds.contains(document.id))
        .length;

    return StudentAccountsRefreshResult(
      adminIds: adminIds,
      adminRoles: adminRoles,
      students: snapshots[1].docs,
      studentCount: studentCount,
    );
  }

  static Future<void> savePermissions({
    required DocumentReference<Map<String, dynamic>> student,
    required Set<String> courseIds,
    required Set<String> examIds,
  }) {
    return student.set({
      'courseIds': courseIds.toList(),
      'examIds': examIds.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> createStudentAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!await AdminAccessService.isSuperAdmin()) {
      throw StateError('إنشاء حسابات الطلاب متاح لـ Super Admin فقط.');
    }
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();
    if (normalizedName.isEmpty ||
        normalizedEmail.isEmpty ||
        password.length < 6) {
      throw ArgumentError(
        'أدخلي الاسم والبريد وكلمة مرور من 6 أحرف على الأقل.',
      );
    }

    final app = await Firebase.initializeApp(
      name: 'student-account-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);
    User? createdUser;
    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) {
        throw StateError('Firebase لم يُرجع الحساب الذي تم إنشاؤه.');
      }

      await createdUser.updateDisplayName(normalizedName);
      await _firestore.collection('users').doc(createdUser.uid).set({
        'name': normalizedName,
        'email': createdUser.email,
        'courseIds': <String>[],
        'examIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } on FirebaseAuthException {
          // Keep the original account-creation or profile-write error.
        }
      }
      rethrow;
    } finally {
      await secondaryAuth.signOut();
      await app.delete();
    }
  }

  static Future<void> setAdminRole({
    required String studentId,
    required String? role,
  }) async {
    if (!await AdminAccessService.isSuperAdmin()) {
      throw StateError('إدارة صلاحيات الأدمن متاحة لـ Super Admin فقط.');
    }
    if (role != null && role != 'admin' && role != 'superAdmin') {
      throw ArgumentError.value(role, 'role', 'دور غير صالح');
    }
    final callerUid = FirebaseAuth.instance.currentUser?.uid;
    if (callerUid == null) {
      throw StateError('انتهت جلسة الدخول. سجلي الدخول مجددًا.');
    }
    if (role == null && callerUid == studentId) {
      throw StateError('لا يمكنك إزالة صلاحية الأدمن من حسابك الحالي.');
    }

    final adminRef = _firestore.collection('admins').doc(studentId);
    await _firestore.runTransaction((transaction) async {
      final targetAdmin = await transaction.get(adminRef);
      if (role != null) {
        final student = await transaction.get(
          _firestore.collection('users').doc(studentId),
        );
        if (!student.exists) {
          throw StateError('لا يوجد ملف طالب لهذا الحساب.');
        }
        transaction.set(adminRef, {
          'role': role,
          'updatedBy': callerUid,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!targetAdmin.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      if (!targetAdmin.exists) return;
      transaction.delete(adminRef);
    });
  }

  static Future<void> deleteAccount(String userId) async {
    await _functions
        .httpsCallable('manageUserAccount')
        .call<Map<String, dynamic>>({'action': 'delete', 'uid': userId});
  }
}
