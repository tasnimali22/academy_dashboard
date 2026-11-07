import 'package:codingacademy_admin/feature/screens/courses/view/courses_page.dart';
import 'package:codingacademy_admin/feature/screens/attendance/view/attendance_page.dart';
import 'package:codingacademy_admin/feature/screens/appointments/view/appointments_page.dart';
import 'package:codingacademy_admin/feature/screens/exams/view/exams_page.dart';
import 'package:codingacademy_admin/feature/screens/students/view/students_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_Item>[
      _Item('الكورسات', Icons.menu_book, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoursesPage()),
        );
      }),
      _Item('الامتحانات', Icons.quiz_outlined, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExamsPage()),
        );
      }),
      _Item('الحضور والغياب', Icons.fact_check_outlined, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AttendancePage()),
        );
      }),
      _Item('الطلاب والصلاحيات', Icons.manage_accounts_outlined, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentsPage()),
        );
      }),
      _Item('المواعيد', Icons.calendar_month, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsPage()),
        );
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final item in items)
            Card(
              child: InkWell(
                onTap:
                    item.onTap ??
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.title}: قريباً')),
                    ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 40),
                    const SizedBox(height: 8),
                    Text(item.title),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Item {
  final VoidCallback? onTap;
  final String title;
  final IconData icon;
  _Item(this.title, this.icon, this.onTap);
}
