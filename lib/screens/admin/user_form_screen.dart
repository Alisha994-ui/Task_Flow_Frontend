import 'package:flutter/material.dart';
import '../../core/coach/coach_target.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin/admin_widgets.dart';

/// Create an account when [user] is null, otherwise edit it.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.user});

  final UserModel? user;

  bool get isEdit => user != null;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  String _role = UserRoles.employee;
  bool _status = true;
  bool _showPassword = false;

  // Snapshot of what the form looked like when it opened, so Back can
  // tell a touched form from an untouched one without a listener on
  // every field.
  late final String _initialRole;
  late final bool _initialStatus;

  @override
  void initState() {
    super.initState();

    final UserModel? user = widget.user;

    _usernameController = TextEditingController(text: user?.username ?? '');
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _passwordController = TextEditingController();

    if (user != null) {
      _role = user.role;
      _status = user.status;
    }

    _initialRole = _role;
    _initialStatus = _status;
  }

  bool get _isDirty {
    return _usernameController.text != (widget.user?.username ?? '') ||
        _firstNameController.text != (widget.user?.firstName ?? '') ||
        _lastNameController.text != (widget.user?.lastName ?? '') ||
        _emailController.text != (widget.user?.email ?? '') ||
        _phoneController.text != (widget.user?.phone ?? '') ||
        _passwordController.text.isNotEmpty ||
        _role != _initialRole ||
        _status != _initialStatus;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final UserProvider users = context.read<UserProvider>();
    final String phone = _phoneController.text.trim();
    UserModel? result;

    if (widget.isEdit) {
      result = await users.updateUser(
        id: widget.user!.id,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: phone.isEmpty ? '' : phone,
        role: _role,
        status: _status,
      );
    } else {
      result = await users.createUser(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: phone.isEmpty ? null : phone,
        role: _role,
        status: _status,
      );
    }

    if (!mounted) {
      return;
    }

    if (result == null) {
      // The API returns field errors like "email: user with this email
      // already exists." - ApiClient already unpacks those.
      _snack(users.error ?? 'Could not save the account', isError: true);

      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserProvider users = context.watch<UserProvider>();

    return DiscardGuard(
      isDirty: () => _isDirty,
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => DiscardGuard.handleBack(context),
      ),
      title: Text(widget.isEdit ? 'Edit user' : 'New user'),
    ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            CoachTarget(
              name: 'user_username',
              child: TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  final String text = value?.trim() ?? '';
  
                  if (text.isEmpty) {
                    return 'Pick a username';
                  }
  
                  if (text.contains(' ')) {
                    return 'No spaces in a username';
                  }
  
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'user_email',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  helperText: 'Must be unique',
                ),
                validator: (String? value) {
                  final String text = value?.trim() ?? '';
  
                  if (text.isEmpty) {
                    return 'An email is required';
                  }
  
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'That does not look like an email';
                  }
  
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
                helperText: 'Optional',
              ),
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'user_role',
              child: DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: <String>{
                  ...UserRoles.assignable,
                  // Keep an existing account's current role selectable
                  // even if it is one (like a legacy Viewer) the app no
                  // longer offers for new picks - editing the rest of
                  // the form must not force a role change nobody asked
                  // for.
                  _role,
                }
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(UserRoles.label(value)),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'user_password',
              child: TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: widget.isEdit ? 'New password' : 'Password',
                  border: const OutlineInputBorder(),
                  helperText: widget.isEdit
                      ? 'Leave empty to keep the current password'
                      : 'At least 8 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (String? value) {
                  final String text = value ?? '';
  
                  // Editing with an empty box means "keep what you have".
                  if (widget.isEdit && text.isEmpty) {
                    return null;
                  }
  
                  if (text.isEmpty) {
                    return 'Set a password';
                  }
  
                  if (text.length < 8) {
                    return 'Use at least 8 characters';
                  }
  
                  return null;
                },
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: Text(
                _status
                    ? 'Can sign in and be assigned work'
                    : 'Account is switched off',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: _status,
              onChanged: (bool value) => setState(() => _status = value),
            ),
            if (widget.isEdit) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Profile pictures are uploaded from the backend admin - the '
                'app does not change them yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: users.isSaving ? null : _save,
            icon: users.isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.isEdit ? 'Save changes' : 'Create user'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
