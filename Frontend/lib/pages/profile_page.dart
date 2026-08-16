// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui' as ui;

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/providers/doctor_cubit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfilePage extends StatefulWidget {
  final Doctor? doctor;

  const ProfilePage({super.key, this.doctor});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _qrBoundaryKey = GlobalKey();

  late Doctor _currentDoctor;
  String? _selectedImagePath;
  String? _selectedImageName;
  Uint8List? _selectedImageBytes;

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _ageController;
  late final TextEditingController _specializationController;
  late final TextEditingController _workPlaceController;
  late final TextEditingController _experienceController;
  late final TextEditingController _locationController;
  late final TextEditingController _languagesController;
  late final TextEditingController _bioController;
  late final TextEditingController _qualificationsController;
  late final TextEditingController _consultationFeeController;
  late final TextEditingController _qrController;

  @override
  void initState() {
    super.initState();

    _currentDoctor =
        widget.doctor ??
        context.read<DoctorCubit>().state.doctor ??
        context.read<AuthCubit>().state.doctor ??
        Doctor(
          id: 'doctor-001',
          name: context.tr('Doctor'),
          email: '',
          phoneNumber: '',
          age: 25,
          profile: const DoctorProfile(
            specialization: '',
            workPlace: '',
            languages: [],
            location: '',
            experience: '',
          ),
        );

    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _ageController = TextEditingController();
    _specializationController = TextEditingController();
    _workPlaceController = TextEditingController();
    _experienceController = TextEditingController();
    _locationController = TextEditingController();
    _languagesController = TextEditingController();
    _bioController = TextEditingController();
    _qualificationsController = TextEditingController();
    _consultationFeeController = TextEditingController();
    _qrController = TextEditingController();

    _applyDoctorToForm(_currentDoctor);

    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _specializationController,
      _qrController,
    ]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final doctorCubit = context.read<DoctorCubit>();
      doctorCubit.syncFromAuthDoctor(context.read<AuthCubit>().state.doctor);
      doctorCubit.loadProfile(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _specializationController.dispose();
    _workPlaceController.dispose();
    _experienceController.dispose();
    _locationController.dispose();
    _languagesController.dispose();
    _bioController.dispose();
    _qualificationsController.dispose();
    _consultationFeeController.dispose();
    _qrController.dispose();
    super.dispose();
  }

  void _applyDoctorToForm(Doctor doctor) {
    _currentDoctor = doctor;
    _nameController.text = doctor.name;
    _emailController.text = doctor.email;
    _phoneController.text = doctor.phoneNumber;
    _ageController.text = doctor.age.toString();
    _specializationController.text = doctor.profile.specialization;
    _workPlaceController.text = doctor.profile.workPlace;
    _experienceController.text = doctor.profile.experience;
    _locationController.text = doctor.profile.location;
    _languagesController.text = doctor.profile.languages.join(', ');
    _bioController.text = doctor.bio ?? '';
    _qualificationsController.text = doctor.profile.qualifications;
    _consultationFeeController.text =
        doctor.profile.consultationFee?.toString() ?? '';
    _qrController.text = doctor.qrCode?.trim().isNotEmpty == true
        ? doctor.qrCode!
        : doctor.email;
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;
    final imageBytes = await image.readAsBytes();

    setState(() {
      _selectedImagePath = image.path;
      _selectedImageName = image.name;
      _selectedImageBytes = imageBytes;
    });
  }

  Future<void> _saveProfile() async {
    final doctorCubit = context.read<DoctorCubit>();
    final payload =
        <String, dynamic>{
          'fullName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? _currentDoctor.age,
          'specialization': _specializationController.text.trim(),
          'workingAt': _workPlaceController.text.trim(),
          'languages': _languagesController.text
              .split(',')
              .map((language) => language.trim())
              .where((language) => language.isNotEmpty)
              .toList(),
          'location': _locationController.text.trim(),
          'qualifications': _qualificationsController.text.trim(),
          'experience':
              int.tryParse(_experienceController.text.trim()) ??
              _currentDoctor.profile.experienceInYears,
          'bio': _bioController.text.trim(),
          'consultationFee':
              double.tryParse(_consultationFeeController.text.trim()) ??
              _currentDoctor.profile.consultationFee,
        }..removeWhere((key, value) {
          if (value == null) return true;
          if (value is String) return value.trim().isEmpty;
          if (value is List) return value.isEmpty;
          return false;
        });

    var success = true;

    if (payload.isNotEmpty) {
      success = await doctorCubit.updateProfile(payload);
      if (!success || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                doctorCubit.state.errorMessage ??
                    context.tr('Failed to save profile.'),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (_selectedImageBytes != null) {
      final photoName = _selectedImageName?.trim().isNotEmpty == true
          ? _selectedImageName!.trim()
          : 'doctor_photo.jpg';
      success = await doctorCubit.uploadPhoto(
        photoBytes: _selectedImageBytes!,
        photoName: photoName,
      );
    }

    if (!mounted) return;

    if (success) {
      final updatedDoctor = doctorCubit.state.doctor;
      if (updatedDoctor != null) {
        setState(() {
          _applyDoctorToForm(updatedDoctor);
          _selectedImagePath = null;
          _selectedImageName = null;
          _selectedImageBytes = null;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Profile information saved successfully!')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          doctorCubit.state.errorMessage ??
              context.tr('Failed to save profile.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _regenerateQr() {
    final base = _currentDoctor.id.isNotEmpty
        ? _currentDoctor.id
        : 'doctor-profile';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _qrController.text = '$base-$timestamp';
    });
  }

  Future<void> _downloadQr() async {
    final qrPreviewNotReadyMessage = context.tr('QR preview is not ready yet.');
    final couldNotExportQrMessage = context.tr('Could not export QR image.');
    final saveQrDialogTitle = context.tr('Save QR Code');
    final qrDownloadedMessage = context.tr('QR code downloaded successfully.');
    final qrDownloadFailedMessage = context.tr('Failed to download QR code.');

    try {
      final boundary =
          _qrBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception(qrPreviewNotReadyMessage);
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception(couldNotExportQrMessage);
      }

      final pngBytes = byteData.buffer.asUint8List();
      final fileName = 'doctor_qr_${DateTime.now().millisecondsSinceEpoch}.png';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: saveQrDialogTitle,
        fileName: fileName,
        bytes: pngBytes,
      );

      if (!mounted || savedPath == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qrDownloadedMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qrDownloadFailedMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAvatar(Color accentColor, {double size = 150}) {
    final avatarPath = _selectedImagePath ?? _currentDoctor.profile.avatar;
    final imageWidget = _buildAvatarImage(avatarPath);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white.withOpacity(0.86), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: imageWidget ?? _buildAvatarFallback(accentColor),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: accentColor,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _pickProfileImage,
              child: Padding(
                padding: EdgeInsets.all(size >= 150 ? 8 : 6),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: size >= 150 ? 18 : 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildAvatarImage(String? avatarPath) {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _buildAvatarFallback(Theme.of(context).colorScheme.primary),
      );
    }

    if (avatarPath == null || avatarPath.trim().isEmpty) {
      return null;
    }

    final trimmedPath = avatarPath.trim();
    final authHeaders = _buildImageAuthHeaders();
    final resolvedUrl = _resolveBackendImageUrl(trimmedPath);
    if (resolvedUrl != null) {
      return Image.network(
        resolvedUrl,
        headers: authHeaders,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _buildAvatarFallback(Theme.of(context).colorScheme.primary),
      );
    }

    if (trimmedPath.startsWith('assets/') || trimmedPath.startsWith('lib/')) {
      return Image.asset(
        trimmedPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _buildAvatarFallback(Theme.of(context).colorScheme.primary),
      );
    }

    if (kIsWeb) {
      return Image.network(
        trimmedPath,
        headers: authHeaders,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _buildAvatarFallback(Theme.of(context).colorScheme.primary),
      );
    }

    return Image.file(
      File(trimmedPath),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          _buildAvatarFallback(Theme.of(context).colorScheme.primary),
    );
  }

  Map<String, String>? _buildImageAuthHeaders() {
    final token = context.read<AuthCubit>().state.token?.trim();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  String? _resolveBackendImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    if (!path.startsWith('/')) {
      return null;
    }

    final apiUri = Uri.tryParse(AuthCubit.defaultApiBaseUrl);
    if (apiUri == null || apiUri.scheme.isEmpty || apiUri.host.isEmpty) {
      return path;
    }

    final normalizedSegments = List<String>.from(apiUri.pathSegments);
    if (normalizedSegments.isNotEmpty && normalizedSegments.last == 'api') {
      normalizedSegments.removeLast();
    }

    final basePath = normalizedSegments.isEmpty
        ? ''
        : '/${normalizedSegments.join('/')}';

    return '${apiUri.scheme}://${apiUri.authority}$basePath$path';
  }

  Widget _buildAvatarFallback(Color accentColor) {
    return Center(child: Icon(Icons.person, size: 52, color: accentColor));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactHeader = screenWidth < 900;
    final horizontalPadding = isCompactHeader ? 16.0 : 24.0;
    final verticalPadding = isCompactHeader ? 20.0 : 24.0;

    final displayName = _nameController.text.trim().isEmpty
        ? context.tr('Doctor Name')
        : _nameController.text.trim();
    final displaySpecialization = _specializationController.text.trim().isEmpty
        ? context.tr('Specialization')
        : _specializationController.text.trim();
    final qrData = _qrController.text.trim().isEmpty
        ? _emailController.text.trim()
        : _qrController.text.trim();

    return BlocConsumer<DoctorCubit, DoctorState>(
      listenWhen: (previous, current) => previous.doctor != current.doctor,
      listener: (context, state) {
        final doctor = state.doctor;
        if (doctor == null) return;
        _applyDoctorToForm(doctor);
      },
      builder: (context, doctorState) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompactHeader ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (doctorState.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(minHeight: 5),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary,
                          // cs.secondary.withOpacity(0.86),
                          cs.primary.withOpacity(0.70),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(
                          theme.brightness == Brightness.dark ? 0.08 : 0.24,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.26),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: isCompactHeader
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildAvatar(cs.primary, size: 124),
                                const SizedBox(height: 16),
                                _buildProfileSummary(
                                  context,
                                  displayName: displayName,
                                  displaySpecialization: displaySpecialization,
                                  centerContent: true,
                                  compact: true,
                                ),
                                const SizedBox(height: 16),
                                _buildQrSection(
                                  context,
                                  qrData,
                                  compact: true,
                                  width: double.infinity,
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAvatar(cs.primary, size: 150),
                                const SizedBox(width: 22),
                                Expanded(
                                  child: _buildProfileSummary(
                                    context,
                                    displayName: displayName,
                                    displaySpecialization:
                                        displaySpecialization,
                                  ),
                                ),
                                const SizedBox(width: 22),
                                _buildQrSection(context, qrData, width: 188),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildCard(
                    context,
                    title: context.tr('Profile Information'),
                    icon: Icons.person_outline,
                    child: _buildResponsiveFields(context, [
                      _buildTextField(
                        context,
                        _nameController,
                        context.tr('Full Name'),
                        icon: Icons.badge_outlined,
                      ),
                      _buildTextField(
                        context,
                        _emailController,
                        context.tr('Email'),
                        readOnly: true,
                        icon: Icons.email_outlined,
                      ),
                      _buildTextField(
                        context,
                        _phoneController,
                        context.tr('Phone'),
                        icon: Icons.phone_outlined,
                      ),
                      _buildTextField(
                        context,
                        _ageController,
                        context.tr('Age'),
                        keyboardType: TextInputType.number,
                        icon: Icons.cake_outlined,
                      ),
                      _buildTextField(
                        context,
                        _bioController,
                        context.tr('About Doctor'),
                        maxLines: 4,
                        icon: Icons.notes_outlined,
                        fullWidth: true,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    context,
                    title: context.tr('Professional Information'),
                    icon: Icons.business_center,
                    child: _buildResponsiveFields(context, [
                      _buildTextField(
                        context,
                        _specializationController,
                        context.tr('Specialization'),
                        icon: Icons.medical_services_outlined,
                      ),
                      _buildTextField(
                        context,
                        _workPlaceController,
                        context.tr('Work Place'),
                        icon: Icons.apartment_outlined,
                      ),
                      _buildTextField(
                        context,
                        _experienceController,
                        context.tr('Years of Experience'),
                        keyboardType: TextInputType.number,
                        icon: Icons.timeline_outlined,
                      ),
                      _buildTextField(
                        context,
                        _locationController,
                        context.tr('Location'),
                        icon: Icons.location_on_outlined,
                      ),
                      _buildTextField(
                        context,
                        _languagesController,
                        context.tr('Languages Spoken'),
                        hintText: context.tr('ar, en'),
                        icon: Icons.translate_outlined,
                      ),
                      _buildTextField(
                        context,
                        _qualificationsController,
                        context.tr('Qualifications'),
                        hintText: context.tr('MBBS, MD'),
                        icon: Icons.school_outlined,
                      ),
                      _buildTextField(
                        context,
                        _consultationFeeController,
                        context.tr('Consultation Fee'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        hintText: context.tr('50'),
                        icon: Icons.payments_outlined,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    context,
                    title: context.tr('QR Code'),
                    icon: Icons.qr_code,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 620;
                        final regenerateButton = OutlinedButton.icon(
                          onPressed: _regenerateQr,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.tr('Regenerate QR')),
                        );
                        final downloadButton = ElevatedButton.icon(
                          onPressed: _downloadQr,
                          icon: const Icon(Icons.download),
                          label: Text(context.tr('Download QR')),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              regenerateButton,
                              const SizedBox(height: 12),
                              downloadButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: regenerateButton),
                            const SizedBox(width: 12),
                            Expanded(child: downloadButton),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSavePanel(context, doctorState),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveFields(BuildContext context, List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760;
        if (!twoColumns) {
          return Column(children: fields);
        }

        final rows = <Widget>[];
        for (var index = 0; index < fields.length; index += 2) {
          final first = fields[index];
          final second = index + 1 < fields.length ? fields[index + 1] : null;
          final firstFullWidth = first.key == const ValueKey('full-width');
          final secondFullWidth = second?.key == const ValueKey('full-width');

          if (firstFullWidth || secondFullWidth || second == null) {
            rows.add(first);
            if (second != null) rows.add(second);
            continue;
          }

          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 16),
                Expanded(child: second),
              ],
            ),
          );
        }

        return Column(children: rows);
      },
    );
  }

  Widget _buildSavePanel(BuildContext context, DoctorState doctorState) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;
          final button = ElevatedButton.icon(
            onPressed: doctorState.isSaving ? null : _saveProfile,
            icon: doctorState.isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(context.tr('Save Changes')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
          );

          final label = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.task_alt, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.tr('Save Changes'),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [label, const SizedBox(height: 14), button],
            );
          }

          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 210),
                child: button,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileSummary(
    BuildContext context, {
    required String displayName,
    required String displaySpecialization,
    bool centerContent = false,
    bool compact = false,
  }) {
    final alignment = centerContent
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          displayName,
          textAlign: centerContent ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: compact ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            displaySpecialization,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _emailController.text.trim(),
          textAlign: centerContent ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white.withOpacity(0.96),
            fontSize: compact ? 13 : 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _phoneController.text.trim(),
          textAlign: centerContent ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white.withOpacity(0.96),
            fontSize: compact ? 13 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard(
    BuildContext context,
    String qrData, {
    bool compact = false,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _qrBoundaryKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: qrData.isEmpty ? 'doctor-profile' : qrData,
                size: compact ? 160 : 130,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('QR Code'),
            style: TextStyle(
              fontSize: 15,
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrSection(
    BuildContext context,
    String qrData, {
    required double width,
    bool compact = false,
  }) {
    return SizedBox(
      width: width,
      child: _buildQrCard(context, qrData, compact: compact),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withOpacity(0.56),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(22), child: child),
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
    bool readOnly = false,
    IconData? icon,
    bool fullWidth = false,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      key: fullWidth ? const ValueKey('full-width') : null,
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            style: TextStyle(
              color: readOnly ? cs.onSurfaceVariant : cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: icon == null ? null : Icon(icon, size: 20),
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant.withOpacity(0.5),
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: readOnly
                  ? cs.surfaceContainerHighest.withOpacity(0.6)
                  : cs.surfaceContainer.withOpacity(0.45),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: cs.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: cs.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
