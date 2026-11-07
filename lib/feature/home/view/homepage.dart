import 'package:codingacademy_admin/core/services/admin_access_service.dart';
import 'package:codingacademy_admin/feature/screens/courses/view/courses_page.dart';
import 'package:codingacademy_admin/feature/screens/attendance/view/attendance_page.dart';
import 'package:codingacademy_admin/feature/screens/attendance/view/attendance_report_page.dart';
import 'package:codingacademy_admin/feature/screens/appointments/view/appointments_page.dart';
import 'package:codingacademy_admin/feature/screens/exams/view/exams_page.dart';
import 'package:codingacademy_admin/feature/screens/students/view/students_page.dart';
import 'package:codingacademy_admin/feature/screens/students/view/student_groups_page.dart';
import 'package:codingacademy_admin/feature/screens/projects/view/projects_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardRole?>(
      future: AdminAccessService.currentRole(),
      builder: (context, roleSnapshot) {
        if (roleSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('لوحة التحكم')),
            body: Center(
              child: Text('تعذر تحميل الصلاحيات: ${roleSnapshot.error}'),
            ),
          );
        }
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roleSnapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('ليس لديك صلاحية الدخول')),
          );
        }
        final isSuperAdmin = roleSnapshot.data == DashboardRole.superAdmin;
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
          _Item('إحصائيات الحضور', Icons.analytics_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceReportPage()),
            );
          }),
          _Item('المواعيد', Icons.calendar_month, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsPage()),
            );
          }),
          _Item('الأعمال والمشاريع', Icons.work_outline, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProjectsPage()),
            );
          }),
        ];
        items.add(
          _Item('الطلاب والمجموعات', Icons.groups_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentGroupsPage()),
            );
          }),
        );
        if (isSuperAdmin) {
          items.add(
            _Item('الطلاب والصلاحيات', Icons.manage_accounts_outlined, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentsPage()),
              );
            }),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isSuperAdmin
                  ? 'لوحة التحكم • Super Admin'
                  : 'لوحة التحكم • Admin',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: GridView.count(
            padding: EdgeInsets.all(16.r),
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
                        Icon(item.icon, size: 40.sp),
                        SizedBox(height: 8.h),
                        Text(item.title),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Item {
  final VoidCallback? onTap;
  final String title;
  final IconData icon;
  _Item(this.title, this.icon, this.onTap);
}
