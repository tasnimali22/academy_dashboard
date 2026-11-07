import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codingacademy_admin/feature/auth/view/login_page.dart';
import 'package:codingacademy_admin/feature/auth/view/widget/loading.dart';
import 'package:codingacademy_admin/feature/auth/view/widget/no_access.dart';
import 'package:codingacademy_admin/feature/home/view/homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Loading();
        }
        final user = snap.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get(),
          builder: (context, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const Loading();
            }
            if (adminSnap.hasError) {
              return NoAccess(message: 'خطأ: ${adminSnap.error}');
            }
            if (adminSnap.data?.exists == true) return const HomePage();
            return const NoAccess(message: 'ليس لديك صلاحية الدخول');
          },
        );
      },
    );
  }
}
