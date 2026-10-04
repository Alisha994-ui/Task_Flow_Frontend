import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/push/push_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      // Tell the backend which phone this person just signed in on.
      // Failures are swallowed inside the service - a missing push is
      // never a reason to block a login.
      await PushService.registerDevice();

      if (!mounted) return;

      final route = AppRoutes.dashboardForRole(
        authProvider.role ?? '',
      );

      Navigator.pushReplacementNamed(context, route);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  /// Passwords are reset by an administrator - there is no self-serve
  /// reset endpoint on the API, so saying so plainly beats a dead link.
  void _showPasswordHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final String username = _usernameController.text.trim();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_reset,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Your administrator resets passwords',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'TaskFlow accounts are managed by your organisation, so '
                  'there is no reset link. Ask whoever set up your account '
                  'and they can set a new password for you.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.mail_outline,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      AppConfig.supportEmail,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text('Tap to write to them'),
                    trailing: Icon(
                      Icons.north_east,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();

                      openMail(
                        context,
                        AppConfig.supportEmail,
                        subject:
                            '${AppConfig.organisationName} - password reset',
                        body: username.isEmpty
                            ? 'Hello,\n\nI cannot sign in to '
                                '${AppConfig.organisationName} and need my '
                                'password reset.\n\nMy username: '
                            : 'Hello,\n\nI cannot sign in to '
                                '${AppConfig.organisationName} and need my '
                                'password reset.\n\nMy username: '
                                '$username\n',
                      );
                    },
                  ),
                ),
                if (AppConfig.supportPhone.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.phone_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        AppConfig.supportPhone,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text('Tap to call'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        openDialer(context, AppConfig.supportPhone);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Mark: four bars, longest done - the shape of a task
                    // list making progress.
                    const _BrandMark(),
                    const SizedBox(height: 28),

                    Text(
                      'TaskFlow',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to pick up where your team left off.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 36),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'Username',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                hintText: 'your.username',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your username';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            Text(
                              'Password',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible =
                                          !_isPasswordVisible;
                                    });
                                  },
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showPasswordHelp,
                                child: const Text('Forgot your password?'),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                return FilledButton(
                                  onPressed: auth.isLoading ? null : _login,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Sign in'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Accounts are created by your administrator.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
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
}

/// Four stacked bars, the top one filled - a checklist getting done.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 56,
        width: 56,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _Bar(width: 28, color: scheme.onPrimary),
            _Bar(width: 20, color: scheme.onPrimary.withValues(alpha: 0.72)),
            _Bar(width: 24, color: scheme.onPrimary.withValues(alpha: 0.48)),
            _Bar(width: 14, color: scheme.onPrimary.withValues(alpha: 0.30)),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3.5,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
