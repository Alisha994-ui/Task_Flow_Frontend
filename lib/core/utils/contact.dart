import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands an email or phone number to whatever app the person already
/// uses for it - Gmail, Outlook, the dialer. TaskFlow does not send
/// anything itself.

/// Opens the mail app with [email] in the To field.
///
/// [subject] and [body] are optional; pass a task or project name and
/// the person starts from something useful instead of a blank screen.
Future<void> openMail(
  BuildContext context,
  String email, {
  String? subject,
  String? body,
}) async {
  final String trimmed = email.trim();

  if (trimmed.isEmpty) {
    _say(context, 'No email address on file');

    return;
  }

  // mailto needs its query encoded by hand - Uri's queryParameters turns
  // spaces into '+', which mail apps show literally.
  final List<String> parts = <String>[
    if (subject != null && subject.isNotEmpty)
      'subject=${Uri.encodeComponent(subject)}',
    if (body != null && body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
  ];

  final Uri uri = Uri.parse(
    'mailto:$trimmed${parts.isEmpty ? '' : '?${parts.join('&')}'}',
  );

  await _launch(context, uri, 'No mail app is set up on this device');
}

/// Opens the dialer with [phone] typed in.
Future<void> openDialer(BuildContext context, String phone) async {
  final String trimmed = phone.trim();

  if (trimmed.isEmpty) {
    _say(context, 'No phone number on file');

    return;
  }

  await _launch(
    context,
    Uri.parse('tel:$trimmed'),
    'Could not open the dialer',
  );
}

Future<void> _launch(
  BuildContext context,
  Uri uri,
  String failureMessage,
) async {
  bool opened = false;

  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }

  if (!opened && context.mounted) {
    _say(context, failureMessage);
  }
}

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
