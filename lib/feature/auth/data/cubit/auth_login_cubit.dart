import 'package:codingacademy_admin/feature/auth/data/cubit/auth_login_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';



class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginState());

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    emit(const LoginState(loading: true));
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (isClosed) return;
      emit(const LoginState());  
    } on FirebaseAuthException catch (e) {
      if (isClosed) return;
      emit(LoginState(error: _message(e.code)));
    } catch (_) {
      if (isClosed) return;
      emit(const LoginState(error: 'حدث خطأ، حاولي مرة أخرى'));
    }
  }

  String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد غير صحيحة';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد أو كلمة المرور غير صحيحة';
      case 'network-request-failed':
        return 'تأكدي من الإنترنت';
      default:
        return 'تعذر تسجيل الدخول';
    }
  }
  @override
  Future<void> close() {
    emailController.dispose();
    passwordController.dispose();
    return super.close();
  }
}