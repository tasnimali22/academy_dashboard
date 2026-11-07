import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

abstract final class AppTextStyles {
  static TextStyle get pageTitle => TextStyle(
    fontSize: 24.sp,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle destructiveAction = TextStyle(color: Colors.red);

  static TextStyle error(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.error,
  );
}
