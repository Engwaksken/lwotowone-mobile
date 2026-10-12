class ApiConfig {
  static const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cms.kemmytech.com/api',
  );
  static String? validate(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        !uri.path.endsWith('/api')) {
      return 'The app connection must use an HTTPS address ending in /api.';
    }
    try {
      if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
        return 'The app connection port is invalid.';
      }
    } on FormatException {
      return 'The app connection port is invalid.';
    }
    final host = uri.host.toLowerCase();
    if (host == 'example.com' ||
        host.endsWith('.example.com') ||
        host == 'your-domain' ||
        host.contains('your-domain')) {
      return 'The app connection has not been configured. Please contact Lwotowone support.';
    }
    return null;
  }
}
