import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:physical_therapy/widgets/custom_button.dart';
import 'package:physical_therapy/widgets/custom_textfield.dart';

enum AuthMode { login, createAccount }

/// Login and Account Creation screen.
///
/// Supports two modes on the same screen:
/// - Login mode
/// - Create account mode (with confirm password field)
///
/// Styling strictly adheres to the app's existing theme and visual language.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AuthMode _mode = AuthMode.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode newMode) {
    setState(() {
      _mode = newMode;
      _errorMessage = null;
      _infoMessage = null;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _onTappedAlreadyHaveAccount() async {
    final email = _emailController.text.trim();
    _switchMode(AuthMode.login);

    if (email.isNotEmpty && email.contains('@')) {
      try {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty && mounted) {
          setState(() {
            _infoMessage = 'هذا البريد مسجل بالفعل، أدخل كلمة المرور.';
          });
        }
      } catch (_) {
        // Firebase email-enumeration protection can make this throw or return empty.
        // Show NOTHING definitive per spec.
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_mode == AuthMode.login) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (_mode == AuthMode.createAccount && e.code == 'email-already-in-use') {
        setState(() {
          _mode = AuthMode.login;
          _errorMessage = 'هذا البريد مسجل بالفعل. سجّل الدخول بدلاً من ذلك.';
        });
      } else {
        setState(() {
          _errorMessage = _localizeAuthError(e.code);
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _localizeAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً. يرجى إدخال 6 أحرف على الأقل.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب. تواصل مع المسؤول.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بالبريد الإلكتروني غير مفعّل حالياً.';
      case 'too-many-requests':
        return 'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً.';
      case 'network-request-failed':
        return 'خطأ في الاتصال بالإنترنت. تحقق من اتصالك.';
      default:
        return 'فشلت العملية. يرجى المحاولة مرة أخرى.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isCreateMode = _mode == AuthMode.createAccount;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo / icon ──────────────────────────────────────────
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.local_hospital_rounded,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ────────────────────────────────────────────────
                  Text(
                    'عيادة العلاج الطبيعي',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCreateMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Email field ──────────────────────────────────────────
                  CustomTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    hint: 'أدخل بريدك الإلكتروني',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }
                      if (!value.contains('@')) {
                        return 'صيغة البريد الإلكتروني غير صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ───────────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      hintText: 'أدخل كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }
                      if (isCreateMode && value.trim().length < 6) {
                        return 'يجب أن لا تقل كلمة المرور عن 6 أحرف';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!_isLoading && !isCreateMode) _submit();
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Confirm Password field (in Create mode) ──────────────
                  if (isCreateMode) ...[
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        hintText: 'أعد إدخال كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى تأكيد كلمة المرور';
                        }
                        if (value != _passwordController.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _submit();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Info message ─────────────────────────────────────────
                  if (_infoMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _infoMessage!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // ── Error message ────────────────────────────────────────
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_errorMessage == 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.') ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => _switchMode(AuthMode.createAccount),
                              child: const Text('إنشاء حساب بهذا البريد الآن'),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ── Main Action button ───────────────────────────────────
                  CustomButton(
                    text: isCreateMode ? 'إنشاء الحساب' : 'تسجيل الدخول',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),

                  // ── Mode Toggle Link ─────────────────────────────────────
                  if (isCreateMode)
                    TextButton(
                      onPressed: _onTappedAlreadyHaveAccount,
                      child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
                    )
                  else
                    TextButton(
                      onPressed: () => _switchMode(AuthMode.createAccount),
                      child: const Text('ليس لديك حساب؟ إنشاء حساب'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
