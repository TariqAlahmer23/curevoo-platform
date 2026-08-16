// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:curevoo_doctor/localization/app_localization.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isResettingPassword = false;
  int _currentStep = 0;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isSendingOtp = true);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _isSendingOtp = false;
      _currentStep = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('OTP sent to your email address.'),
        ),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

    setState(() => _isVerifyingOtp = true);
    await Future.delayed(const Duration(seconds: 1));

    const demoOtp = '123456';
    final enteredOtp = _otpController.text.trim();
    final isCorrect = enteredOtp == demoOtp;

    if (!mounted) return;
    setState(() => _isVerifyingOtp = false);

    if (!isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Invalid OTP. Please try again.')),
        ),
      );
      return;
    }

    setState(() => _currentStep = 2);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('OTP verified successfully.')),
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isResettingPassword = true);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isResettingPassword = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Password updated successfully.')),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Forgot Password')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.primaryColor,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 520,
              ),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 20 : 28),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(theme),
                    const SizedBox(height: 24),
                    if (_currentStep == 0) _buildEmailStep(theme),
                    if (_currentStep == 1) _buildOtpStep(theme),
                    if (_currentStep == 2) _buildResetPasswordStep(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    final cs = theme.colorScheme;
    final steps = [
      context.tr('Email'),
      context.tr('OTP'),
      context.tr('Password'),
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? cs.primary.withOpacity(isCompleted ? 0.18 : 0.12)
                        : cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive || isCompleted
                          ? cs.primary.withOpacity(0.35)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isActive || isCompleted
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isActive || isCompleted
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[index],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isActive || isCompleted
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != steps.length - 1)
                Container(
                  width: 12,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: index < _currentStep
                      ? cs.primary.withOpacity(0.5)
                      : cs.outlineVariant,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmailStep(ThemeData theme) {
    final cs = theme.colorScheme;

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Reset by Email'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('Enter your email address to receive a one-time code.'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.tr('Email Address'),
              hintText: context.tr('doctor@example.com'),
              prefixIcon: Icon(Icons.email_outlined, color: theme.primaryColor),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return context.tr('Please enter your email');
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                return context.tr('Please enter a valid email');
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSendingOtp ? null : _sendOtp,
              child: _isSendingOtp
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onPrimary,
                      ),
                    )
                  : Text(context.tr('Send OTP')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(ThemeData theme) {
    final cs = theme.colorScheme;

    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Verify OTP'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('Enter the OTP sent to your email.'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emailController.text.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: context.tr('OTP Code'),
              hintText: context.tr('6-digit code'),
              counterText: '',
              prefixIcon: Icon(
                Icons.password_outlined,
                color: theme.primaryColor,
              ),
            ),
            validator: (value) {
              final otp = value?.trim() ?? '';
              if (otp.isEmpty) return context.tr('Please enter the OTP');
              if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                return context.tr('OTP must be 6 digits');
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _isVerifyingOtp
                ? null
                : () => setState(() => _currentStep = 0),
            child: Text(context.tr('Change Email')),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isVerifyingOtp ? null : _verifyOtp,
              child: _isVerifyingOtp
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onPrimary,
                      ),
                    )
                  : Text(context.tr('Verify OTP')),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('Demo OTP: 123456'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordStep(ThemeData theme) {
    final cs = theme.colorScheme;

    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Reset Password'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('Create a new password for your account.'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emailController.text.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: context.tr('New Password'),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: theme.primaryColor,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.isEmpty) return context.tr('Please enter a new password');
              if (password.length < 6) {
                return context.tr('Password must be at least 6 characters');
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: context.tr('Confirm Password'),
              prefixIcon: Icon(
                Icons.lock_person_outlined,
                color: theme.primaryColor,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return context.tr('Please confirm your password');
              }
              if (value != _newPasswordController.text) {
                return context.tr('Passwords do not match');
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isResettingPassword ? null : _resetPassword,
              child: _isResettingPassword
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onPrimary,
                      ),
                    )
                  : Text(context.tr('Save New Password')),
            ),
          ),
        ],
      ),
    );
  }
}




