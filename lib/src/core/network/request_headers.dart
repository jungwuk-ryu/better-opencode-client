import '../connection/connection_models.dart';

const browserLikeUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/123.0 Safari/537.36';

Map<String, String> buildRequestHeaders(
  ServerProfile profile, {
  required String accept,
  bool jsonBody = false,
}) {
  final headers = <String, String>{
    'accept': accept,
    'user-agent': browserLikeUserAgent,
  };
  if (jsonBody) {
    headers['content-type'] = 'application/json';
  }
  final authHeader = profile.basicAuthHeader;
  if (authHeader != null) {
    headers['authorization'] = authHeader;
  }
  return headers;
}
