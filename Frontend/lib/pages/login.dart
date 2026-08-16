// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:curevoo_doctor/pages/forgot_password.dart';
import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onSignUpPressed;

  const LoginPage({
    super.key,
    required this.onSignUpPressed,
  });

  @override
  LoginPageState createState() => LoginPageState();
}


class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showedInitialAuthError = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMePreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showedInitialAuthError) return;
      final authState = context.read<AuthCubit>().state;
      final errorMessage = authState.errorMessage?.trim();
      if (authState.status == AuthStatus.unauthenticated &&
          errorMessage != null &&
          errorMessage.isNotEmpty) {
        _showedInitialAuthError = true;
        _showErrorMessage(
          errorMessage,
          fallback: context.tr('Please sign in again.'),
        );
      }
    });
  }

  Future<void> _loadRememberMePreference() async {
    final rememberMe = await context.read<AuthCubit>().readRememberMePreference();
    if (!mounted) return;
    setState(() => _rememberMe = rememberMe);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await context.read<AuthCubit>().login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        _showErrorMessage(
          context.read<AuthCubit>().state.errorMessage,
          fallback: context.tr('Something went wrong. Please try again.'),
        );
      }
    }
  }

  void _showErrorMessage(String? rawMessage, {required String fallback}) {
    final cs = Theme.of(context).colorScheme;
    final message = _resolveErrorMessage(rawMessage, fallback: fallback);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _resolveErrorMessage(String? rawMessage, {required String fallback}) {
    final message = rawMessage?.trim();
    if (message == null || message.isEmpty) {
      return fallback;
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;
    
    return Scaffold(
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
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 800,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Responsive Layout
                      if (isMobile) ...[
                        // Mobile Layout - Only Login Form with App Image
                        _buildMobileLayout(theme),
                      ] else ...[
                        // Desktop/Tablet Layout - Side by Side
                        _buildDesktopLayout(theme, isTablet),
                      ],
                      
                      const SizedBox(height: 40),
                      
                      // Footer
                      Text('',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, bool isTablet) {
    final cs = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: isTablet ? 700 : 650,
        minHeight: 500,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.08,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Start Side - Branding
          Flexible(
            flex: isTablet ? 5 : 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primaryColor,
                    theme.primaryColorDark,
                    theme.focusColor,
                  ],
                ),
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(40),
                  bottomStart: Radius.circular(40),
                ),
              ),
              child: _buildBrandingSection(theme),
            ),
          ),

          // End Side - Login Form
          Flexible(
            flex: isTablet ? 7 : 6,
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadiusDirectional.only(
                  topEnd: Radius.circular(40),
                  bottomEnd: Radius.circular(40),
                ),
              ),
              child: _buildLoginForm(theme, isTablet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    final cs = theme.colorScheme;

    return Column(
      children: [
        // App Logo/Image at the top for mobile
        Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // App Logo with Image
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.2),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'lib/images/curvoo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.medical_services,
                        size: 50,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // App Name
              Text(
                context.tr('CureVoo'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Tagline
              Text('',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        // Login Form Card for mobile
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  theme.brightness == Brightness.dark ? 0.2 : 0.1,
                ),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildLoginForm(theme, false),
        ),
        
        const SizedBox(height: 30),
        
        // Features for mobile (below login form)
        Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.primaryColor.withOpacity(0.9),
                theme.primaryColorDark,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                context.tr('Why Choose CureVoo?'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              _buildMobileFeatureItem(
                icon: Icons.description,
                text: context.tr('Comprehensive Diagnosis & Treatment Plans'),
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              _buildMobileFeatureItem(
                icon: Icons.medical_services,
                text: context.tr('Secure Patient Records Management'),
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              _buildMobileFeatureItem(
                icon: Icons.schedule,
                text: context.tr('Efficient Appointment Scheduling'),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrandingSection(ThemeData theme) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'lib/images/curvoo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.medical_services,
                      size: 60,
                      color: theme.primaryColor,
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // App Name
            Text(
              context.tr('CureVoo'),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Tagline
            Text('',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Decorative Divider
            Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.symmetric(vertical: 20),
            ),
            
            // Features
            Column(
              children: [
                _buildFeatureItem(
                  icon: Icons.description,
                  text: 'Diagnosis & Treatment Plans',
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.medical_services,
                  text: 'Patient Records',
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(
                  icon: Icons.schedule,
                  text: 'Appointment Management',
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme, bool isTablet) {
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Welcome Text (only shown on desktop/tablet, not on mobile since we have it above)
              if (!isTablet) const SizedBox(height: 8) else ...[
                Text(
                  context.tr('Welcome Back, Doctor'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    height: 1.2,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  context.tr('Sign in to access your dashboard'),
                  style: TextStyle(
                    fontSize: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
              
              // Email Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Email Address'),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: context.tr('Enter your email'),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: theme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Please enter your email');
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Password'),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: context.tr('Enter your password'),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: theme.primaryColor,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: theme.primaryColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Please enter your password');
                      }
                      if (value.length < 6) {
                        return context.tr('Password must be at least 6 characters');
                      }
                      return null;
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Theme(
                        data: ThemeData(
                          unselectedWidgetColor: cs.onSurfaceVariant,
                        ),
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Text(
                        context.tr('Remember me'),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: Text(
                      context.tr('Forgot Password?'),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: theme.primaryColor.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: cs.onPrimary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.tr('Sign In'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.arrow_forward,
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Divider with OR
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: cs.outlineVariant,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      context.tr('OR'),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: cs.outlineVariant,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Sign Up Link
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    context.tr("Don't have an account? "),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onSignUpPressed,
                    child: Text(
                      context.tr('Create Account'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Privacy Notice
              Text(
                context.tr(
                  'By signing in, you agree to our Terms of Service and Privacy Policy',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  

  Widget _buildFeatureItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFeatureItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}





