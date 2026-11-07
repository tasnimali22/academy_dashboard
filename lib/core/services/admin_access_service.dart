import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum DashboardRole { admin, superAdmin }

class AdminAccessService {
  static const superAdminEmail = 'tasnimali051@gmail.com';

  static final _firestore = FirebaseFirestore.instance;

  static Future<DashboardRole?> currentRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (user.email?.toLowerCase() == superAdminEmail) {
      return DashboardRole.superAdmin;
    }

    final admin = await _firestore.collection('admins').doc(user.uid).get();
    if (!admin.exists) return null;
    return admin.data()?['role'] == 'superAdmin'
        ? DashboardRole.superAdmin
        : DashboardRole.admin;
  }

  static Future<bool> isSuperAdmin() async =>
      await currentRole() == DashboardRole.superAdmin;

  static Future<String> requireUserId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('سجلي الدخول أولاً.');
    return uid;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchContent(
    String collection,
  ) async* {
    final uid = await requireUserId();
    final elevated = await isSuperAdmin();
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (!elevated) query = query.where('createdBy', isEqualTo: uid);
    yield* query.snapshots();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> loadContent(
    String collection,
  ) async {
    final uid = await requireUserId();
    final elevated = await isSuperAdmin();
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (!elevated) query = query.where('createdBy', isEqualTo: uid);
    return query.get();
  }
}
