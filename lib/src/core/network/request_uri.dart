Uri buildRequestUri(
  Uri baseUri, {
  required String path,
  Map<String, String>? queryParameters,
}) {
  final basePath = switch (baseUri.path) {
    '' => '/',
    final value when value.endsWith('/') => value,
    final value => '$value/',
  };
  final resolvedPath = path.startsWith('/') ? path.substring(1) : path;
  final mergedQueryParameters = <String, String>{
    ...baseUri.queryParameters,
    ...?queryParameters,
  };
  final normalizedBaseUri = baseUri.replace(
    path: basePath,
    queryParameters: baseUri.hasQuery ? baseUri.queryParameters : null,
  );

  return normalizedBaseUri
      .resolve(resolvedPath)
      .replace(
        queryParameters: mergedQueryParameters.isEmpty
            ? null
            : mergedQueryParameters,
      );
}
