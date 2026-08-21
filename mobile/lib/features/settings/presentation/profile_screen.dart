import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/foundation/pm_text_input.dart';
import '../../../theme/paymuster_tokens.dart';
import '../data/profile_api_client.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  ProfileSnapshot? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final profile = await ref.read(profileApiProvider).getProfile();
      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  void _applyProfile(ProfileSnapshot profile) {
    _nameController.text = profile.name;
    _phoneController.text = profile.phone ?? '';
  }

  Future<void> _saveProfile() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await ref
          .read(profileApiProvider)
          .updateProfile(
            name: _nameController.text,
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
          );
      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _profile = profile;
        _editing = false;
      });
      _showMessage('Profile saved successfully.');
    } catch (error) {
      if (mounted) _showError(_message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showError('The selected avatar is empty.');
        return;
      }
      final extension = file.name.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      setState(() => _uploadingAvatar = true);
      final profile = await ref
          .read(profileApiProvider)
          .uploadAvatar(bytes: bytes, mimeType: mimeType);
      if (!mounted) return;
      setState(() => _profile = profile);
      _showMessage('Profile picture updated.');
    } catch (error) {
      if (mounted) _showError(_message(error));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Exception: '), '');

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final background = isDark
        ? PMColors.bgPrimaryDark
        : PMColors.bgPrimaryLight;
    final surface = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        backgroundColor: surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _editing ? 'Save profile' : 'Edit profile',
            onPressed: _loading || _saving
                ? null
                : (_editing
                      ? _saveProfile
                      : () => setState(() => _editing = true)),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_editing ? Icons.check : Icons.edit, color: textColor),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ProfileMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Profile unavailable',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _loadProfile,
            )
          : _profile == null
          ? _ProfileMessage(
              icon: Icons.person_outline,
              title: 'Profile unavailable',
              message: 'Your profile could not be loaded.',
              actionLabel: 'Retry',
              onAction: _loadProfile,
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: _ProfileContent(
                profile: _profile!,
                formKey: _formKey,
                nameController: _nameController,
                phoneController: _phoneController,
                editing: _editing,
                uploadingAvatar: _uploadingAvatar,
                textColor: textColor,
                onPickAvatar: _editing ? _pickAvatar : null,
                onOpenDocuments: () => context.push('/app/documents'),
              ),
            ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.editing,
    required this.uploadingAvatar,
    required this.textColor,
    required this.onPickAvatar,
    required this.onOpenDocuments,
  });

  final ProfileSnapshot profile;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool editing;
  final bool uploadingAvatar;
  final Color textColor;
  final VoidCallback? onPickAvatar;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final verification = profile.verification;
    final avatar = profile.avatarUrl;
    final initials = profile.name.trim().isEmpty
        ? 'U'
        : profile.name.trim().substring(0, 1).toUpperCase();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(PMSpacing.s6),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: PMColors.brandPrimaryLight,
                backgroundImage: avatar == null
                    ? null
                    : NetworkImage(avatar.toString()),
                child: avatar == null
                    ? Text(
                        initials,
                        style: PMTypography.displayLarge.copyWith(
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              if (editing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: PMColors.accentOrangeLight,
                    child: IconButton(
                      tooltip: 'Change profile picture',
                      onPressed: uploadingAvatar ? null : onPickAvatar,
                      icon: uploadingAvatar
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: PMSpacing.s6),
        Form(
          key: formKey,
          child: Column(
            children: [
              PMTextInput(
                labelText: 'Full Name',
                controller: nameController,
                enabled: editing,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: PMSpacing.s3),
              PMTextInput(
                labelText: 'Phone Number',
                controller: phoneController,
                enabled: editing,
              ),
              const SizedBox(height: PMSpacing.s3),
              PMTextInput(
                labelText: 'Email',
                controller: TextEditingController(text: profile.email),
                enabled: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: PMSpacing.s6),
        Text(
          'Work Details',
          style: PMTypography.title.copyWith(color: textColor),
        ),
        const SizedBox(height: PMSpacing.s2),
        _InfoTile(
          label: 'Company',
          value: profile.organization?.name ?? 'Unassigned',
        ),
        _InfoTile(label: 'Role', value: profile.role),
        _InfoTile(label: 'Public ID', value: profile.publicId ?? 'Unavailable'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(
            'Documents',
            style: PMTypography.body.copyWith(color: textColor),
          ),
          subtitle: Text(
            '${verification.total} uploaded · ${verification.verified} verified · ${verification.pending} pending · ${verification.rejected} rejected',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenDocuments,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_outlined),
          title: Text(
            'Verification',
            style: PMTypography.body.copyWith(color: textColor),
          ),
          subtitle: Text(
            '${verification.verified} of ${verification.total} verified',
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PMSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: PMSpacing.s4),
            Text(title, style: PMTypography.headline),
            const SizedBox(height: PMSpacing.s2),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: PMSpacing.s5),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
