/// Things that change per deployment, kept in one place.
class AppConfig {
  const AppConfig._();

  /// Where someone writes when they cannot sign in. Shown on the login
  /// screen - change it to your own address before handing the app out.
  static const String supportEmail = 'admin@yourcompany.com';

  /// Optional. Leave empty to show only the email.
  static const String supportPhone = '';

  /// Name used in the password-reset message.
  static const String organisationName = 'TaskFlow';
}
