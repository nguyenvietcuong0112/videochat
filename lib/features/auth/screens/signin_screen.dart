
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController(); // Controller cho tên hiển thị

  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final authService = Provider.of<AuthService>(context, listen: false);

      try {
        if (_isLogin) {
          await authService.signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
        } else {
          await authService.signUpWithEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.message ?? 'Đã có lỗi xảy ra.';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_chat_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  _isLogin ? 'Đăng nhập' : 'Tạo tài khoản',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                // Trường Tên hiển thị (chỉ hiển thị khi đăng ký)
                if (!_isLogin)
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập tên của bạn' : null,
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || !value.contains('@')) ? 'Vui lòng nhập email hợp lệ' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.length < 6) ? 'Mật khẩu phải có ít nhất 6 ký tự' : null,
                ),
                const SizedBox(height: 24),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          child: Text(_isLogin ? 'Đăng nhập' : 'Đăng ký'),
                        ),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = '';
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Chưa có tài khoản? Đăng ký ngay'
                        : 'Đã có tài khoản? Đăng nhập',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
