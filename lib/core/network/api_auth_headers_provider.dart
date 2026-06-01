import 'package:lexrush/core/auth/auth_tokens.dart';
import 'package:lexrush/core/auth/token_store.dart';

class ApiAuthHeadersProvider {
  const ApiAuthHeadersProvider({required TokenStore tokenStore})
    : _tokenStore = tokenStore;

  final TokenStore _tokenStore;

  Future<Map<String, String>> authorizationHeaders() async {
    final AuthTokens? tokens = await _tokenStore.readTokens();
    if (tokens == null) return <String, String>{};
    return <String, String>{'Authorization': 'Bearer ${tokens.accessToken}'};
  }
}
