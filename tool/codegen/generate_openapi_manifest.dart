import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/codegen/generate_openapi_manifest.dart <input-spec.json> <output.json>',
    );
    exitCode = 64;
    return;
  }

  final input = File(args[0]);
  final output = File(args[1]);
  final spec = jsonDecode(await input.readAsString()) as Map<String, Object?>;
  final paths =
      ((spec['paths'] as Map?) ?? const {}).keys.cast<String>().toList()
        ..sort();
  final manifest = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'pathCount': paths.length,
    'paths': paths,
  };

  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
}
