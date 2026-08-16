// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/widgets/password_validator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class SignUpPage extends StatefulWidget {
  final VoidCallback onLoginPressed;

  const SignUpPage({super.key, required this.onLoginPressed});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // New profile fields controllers
  final _specializationController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _experienceController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  Uint8List? _selectedAvatarBytes; // Store image bytes
  String? _selectedAvatarName; // Store file name
  bool _isUploadingImage = false;
  final List<String> _selectedLanguages = ['English']; // Default language

  // Available languages for selection
  final List<String> _availableLanguages = [
    'English',
    'Arabic',
    'French',
    'Spanish',
    'German',
    'Chinese',
    'Hindi',
    'Russian',
    'Portuguese',
    'Japanese',
  ];

  // Experience options
  final List<String> _experienceOptions = [
    '0-2 years',
    '2-5 years',
    '5-10 years',
    '10-15 years',
    '15+ years',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _specializationController.dispose();
    _workplaceController.dispose();
    _experienceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        _showErrorMessage(
          context.tr('Please agree to terms and conditions'),
          fallback: context.tr('Something went wrong. Please try again.'),
        );
        return;
      }

      setState(() => _isLoading = true);

      final experienceYears = _parseExperienceYears(
        _experienceController.text.trim(),
      );

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'specialization': _specializationController.text.trim(),
        'workplace': _workplaceController.text.trim(),
        'experience': experienceYears,
        'location': _locationController.text.trim(),
        'languages': _selectedLanguages,
        'password': _passwordController.text,
      };

      if (_selectedAvatarBytes != null && _selectedAvatarName != null) {
        payload['photoBytes'] = _selectedAvatarBytes!;
        payload['photoName'] = _selectedAvatarName!;
      }

      final success = await context.read<AuthCubit>().signup(payload);

      if (!mounted) return;

      if (!success) {
        _showErrorMessage(
          context.read<AuthCubit>().state.errorMessage,
          fallback: context.tr('Something went wrong. Please try again.'),
        );
      } else {
        _showSuccessMessage(context.tr('Account created successfully'));
        if (!context.read<AuthCubit>().state.isAuthenticated) {
          widget.onLoginPressed();
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
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

  void _showSuccessMessage(String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: cs.secondary,
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

  int _parseExperienceYears(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }

  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.tr('Select Languages')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._availableLanguages.map((language) {
                      return CheckboxListTile(
                        title: Text(language),
                        value: _selectedLanguages.contains(language),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedLanguages.add(language);
                            } else {
                              _selectedLanguages.remove(language);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Cancel')),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Text(context.tr('Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _isUploadingImage = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        if (file.size > 5 * 1024 * 1024) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('File size must be less than 5 MB')),
              backgroundColor: cs.error,
            ),
          );
          return;
        }

        setState(() {
          _selectedAvatarBytes = file.bytes;
          _selectedAvatarName = file.name;
        });
      }
    } catch (e) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Failed to upload image. Please try again.'),
          ),
          backgroundColor: cs.error,
        ),
      );
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Widget _buildImagePreview() {
    final cs = Theme.of(context).colorScheme;

    if (_isUploadingImage) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHigh,
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_selectedAvatarBytes != null) {
      return ClipOval(
        child: Image.memory(
          _selectedAvatarBytes!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHigh,
              ),
              child: Icon(Icons.error, color: cs.onSurface),
            );
          },
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainer,
        ),
        child: Icon(Icons.person_add, size: 40, color: cs.onSurfaceVariant),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.scaffoldBackgroundColor, theme.primaryColor],
          ),
        ),
        child: Center(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo and Title
                    _buildHeader(context),
                    const SizedBox(height: 40),

                    // Sign Up Card
                    Card(
                      color: cs.surface,
                      elevation: isDark ? 2 : 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Create Doctor Account'),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr(
                                  'Complete your profile to get started with CureVoo',
                                ),
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 32),

                              // Section 1: Personal Information
                              _buildSectionHeader(
                                context.tr('Personal Information'),
                              ),
                              const SizedBox(height: 16),

                              // Name and Email Row
                              _buildResponsivePair(
                                left: TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Full Name'),
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your full name';
                                    }
                                    return null;
                                  },
                                ),
                                right: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Email Address'),
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(
                                      r'^[^@]+@[^@]+\.[^@]+',
                                    ).hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Phone and Age Row
                              _buildResponsivePair(
                                left: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Phone Number'),
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter phone number';
                                    }
                                    return null;
                                  },
                                ),
                                right: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Age'),
                                    prefixIcon: const Icon(
                                      Icons.calendar_today,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your age';
                                    }
                                    final age = int.tryParse(value);
                                    if (age == null || age < 25 || age > 80) {
                                      return 'Age must be between 25-80';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Profile Picture Section
                              _buildProfilePictureSection(),
                              const SizedBox(height: 32),

                              // Section 2: Professional Information
                              _buildSectionHeader(
                                context.tr('Professional Information'),
                              ),
                              const SizedBox(height: 16),

                              // Specialization and Workplace
                              _buildResponsivePair(
                                left: TextFormField(
                                  controller: _specializationController,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Specialization'),
                                    hintText: context.tr('e.g., Cardiology'),
                                    prefixIcon: const Icon(
                                      Icons.medical_services_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your specialization';
                                    }
                                    return null;
                                  },
                                ),
                                right: TextFormField(
                                  controller: _workplaceController,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Workplace'),
                                    hintText: context.tr('e.g., City Hospital'),
                                    prefixIcon: const Icon(Icons.work_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your workplace';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Experience and Location
                              _buildResponsivePair(
                                left: DropdownButtonFormField<String>(
                                  value: _experienceController.text.isEmpty
                                      ? null
                                      : _experienceController.text,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Experience'),
                                    prefixIcon: const Icon(
                                      Icons.timeline_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: _experienceOptions.map((exp) {
                                    return DropdownMenuItem<String>(
                                      value: exp,
                                      child: Text(exp),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _experienceController.text = value ?? '';
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select experience';
                                    }
                                    return null;
                                  },
                                ),
                                right: TextFormField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Location'),
                                    hintText: context.tr(
                                      'e.g., Damascus, Syria',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.location_on_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your location';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Languages Selection
                              GestureDetector(
                                onTap: _showLanguageSelectionDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: cs.outline),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.language_outlined,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr('Languages'),
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedLanguages.isEmpty
                                                  ? context.tr(
                                                      'Select languages',
                                                    )
                                                  : _selectedLanguages.join(
                                                      ', ',
                                                    ),
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Section 3: Account Security
                              _buildSectionHeader(
                                context.tr('Account Security'),
                              ),
                              const SizedBox(height: 16),

                              // Password Fields
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: context.tr('Password'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.tr(
                                      'Please enter a password',
                                    );
                                  }
                                  final formatError =
                                      PasswordValidator.validateFormat(value);
                                  if (formatError != null) {
                                    return context.tr(formatError);
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: context.tr('Confirm Password'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Terms and Conditions
                              Row(
                                children: [
                                  Checkbox(
                                    value: _agreeToTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _agreeToTerms = value!;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'I agree to the ',
                                          ),
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () {
                                                // Show terms dialog
                                              },
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () {
                                                // Show privacy policy dialog
                                              },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Sign Up Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.onPrimary,
                                          ),
                                        )
                                      : Text(
                                          context.tr('Create Account'),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onPrimary,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Login Link
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    context.tr('Already have an account?'),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onLoginPressed,
                                    child: Text(
                                      context.tr('Sign In'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Footer
                    Text(
                      context.tr(
                        'Your information is securely encrypted and protected',
                      ),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsivePair({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }

        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Profile Picture (Optional)'),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Profile picture container
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Profile picture preview
                _buildImagePreview(),

                const SizedBox(width: 16),

                // Upload text and button
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAvatarBytes != null
                            ? 'Profile Picture Selected'
                            : 'Add Profile Picture',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isUploadingImage
                            ? 'Uploading...'
                            : _selectedAvatarBytes != null
                            ? '${_selectedAvatarName ?? 'Image'} (Click to change)'
                            : 'Click to choose a photo from your device',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedAvatarBytes != null
                                  ? 'Change Photo'
                                  : 'Upload Photo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          context.tr('Accepted formats: JPG, PNG, GIF, WEBP (max 5MB)'),
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        // Remove button if image is selected
        if (_selectedAvatarBytes != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedAvatarBytes = null;
                    _selectedAvatarName = null;
                  });
                },
                icon: const Icon(Icons.delete, size: 16),
                label: Text(context.tr('Remove')),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: cs.primary.withOpacity(0.2), width: 3),
          ),
          child: ClipOval(
            child: Image.asset(
              'lib/images/curvoo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.medical_services,
                  size: 50,
                  color: cs.onPrimary,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('CureVoo'),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Doctor Registration Portal'),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
