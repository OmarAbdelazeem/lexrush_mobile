class ApiConfig {
  const ApiConfig({required this.baseUrl});

  factory ApiConfig.fromEnvironment() {
    const String configuredBaseUrl = String.fromEnvironment(
      'LEXRUSH_API_BASE_URL',
      defaultValue: _defaultBaseUrl,
    );
    return const ApiConfig(baseUrl: configuredBaseUrl);
  }

  static const String _defaultBaseUrl = 'http://10.0.2.2:3000';

  final String baseUrl;
}
