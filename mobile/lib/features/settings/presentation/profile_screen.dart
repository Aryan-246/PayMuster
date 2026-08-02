import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/paymuster_tokens.dart';
import '../../../components/foundation/pm_text_input.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _bloodGroupController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController(text: '+91 9876543210');
    _emailController = TextEditingController();
    _emergencyContactController = TextEditingController(text: '+91 9876543211');
    _bloodGroupController = TextEditingController(text: 'O+');
    
    // Load initial data from auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      if (authState.user != null) {
        _nameController.text = authState.user!.name ?? '';
        _emailController.text = authState.user!.email;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        if (_formKey.currentState!.validate()) {
          final currentUser = ref.read(authControllerProvider).user;
          if (currentUser != null) {
            final updatedUser = currentUser.copyWith(
              name: _nameController.text,
            );
            ref.read(authControllerProvider.notifier).updateUser(updatedUser);
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully')),
          );
          _isEditing = false;
        }
      } else {
        _isEditing = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : PMColors.textPrimaryLight;
    final bgColor = isDark ? PMColors.bgPrimaryDark : PMColors.bgPrimaryLight;
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Profile', style: PMTypography.title.copyWith(color: textColor)),
        backgroundColor: isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit, color: textColor),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: PMColors.brandPrimaryLight,
                      child: Text(
                        (user?.name?.isNotEmpty == true) ? user!.name!.substring(0, 1).toUpperCase() : 'U',
                        style: PMTypography.displayLarge.copyWith(color: Colors.white),
                      ),
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: PMColors.accentOrangeLight,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            onPressed: () {
                              // TODO: Implement photo picker
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              PMTextInput(
                labelText: 'Full Name',
                controller: _nameController,
                enabled: _isEditing,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              PMTextInput(
                labelText: 'Email',
                controller: _emailController,
                enabled: false, // Usually email is not editable directly here
              ),
              const SizedBox(height: 16),
              PMTextInput(
                labelText: 'Phone Number',
                controller: _phoneController,
                enabled: _isEditing,
              ),
              const SizedBox(height: 16),
              PMTextInput(
                labelText: 'Emergency Contact',
                controller: _emergencyContactController,
                enabled: _isEditing,
              ),
              const SizedBox(height: 16),
              PMTextInput(
                labelText: 'Blood Group',
                controller: _bloodGroupController,
                enabled: _isEditing,
              ),
              const SizedBox(height: 24),
              Text(
                'Work Details',
                style: PMTypography.title.copyWith(color: textColor),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.business),
                title: Text('Company', style: PMTypography.body.copyWith(color: textColor)),
                subtitle: const Text('PayMuster Mock Org'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge),
                title: Text('Role', style: PMTypography.body.copyWith(color: textColor)),
                subtitle: Text(user?.role.name.toUpperCase() ?? 'UNKNOWN'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description),
                title: Text('Documents', style: PMTypography.body.copyWith(color: textColor)),
                subtitle: const Text('3 uploaded (ID, Address, Certificates)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to Documents screen
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
