import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/directory.dart';
import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/hash.dart';
import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/path.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Downloads an HTML file or resource (js/css/image) retrying if
/// necessary and checking for problematic cases.
/// With local cache so that the same file is not downloaded twice in the same day.
Future<(Uint8List?, String)> downloadFile(Uri uri, String spaceName) async {
  //
  // Local cached file posibility.
  //
  const cacheExpires = Duration(days: 1);
  // const cacheExpires = Duration(seconds: 1);

  final tempDirPath = getSystemTempDirectoryPath();
  if (tempDirPath.isEmpty) return (null, '');

  final cacheDir = Directory(p.join(tempDirPath, spaceName));
  if (!cacheDir.existsSync()) await cacheDir.create();

  final checksum = createChecksum(uri.toString());
  final cachedFile = File(
    p.join(cacheDir.path, checksum),
  );
  final cachedJsonFile = File(
    p.join(cacheDir.path, '$checksum-response-headers.json'),
  );

  if (cachedFile.existsSync()) {
    if (DateTime.now().difference(cachedFile.lastModifiedSync()) > cacheExpires) {
      await cachedJsonFile.delete();
      await cachedFile.delete();
    } else {
      print('downloadFile (cached): $uri');
      // final headers = Map<String, List<String>>.from(
      //   jsonDecode(await cachedJsonFile.readAsString()) as Map<dynamic, dynamic>,
      // );

      final headers =
          (jsonDecode(await cachedJsonFile.readAsString()) as Map<dynamic, dynamic>).map(
        (key, value) => MapEntry(
          key as String,
          List<String>.from(value as List<dynamic>),
        ),
      );

      final contentType = headers['content-type']!.first;
      return (await cachedFile.readAsBytes(), contentType);
    }
  }

  //
  // Remote file.
  //

  print('downloadFile: $uri');

  var attemptCount = 0;
  while (attemptCount < 50) {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 60);

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final bodyBytes = Uint8List.fromList(<int>[
          for (final bytes in await response.toList()) ...bytes,
        ]);
        await cachedFile.writeAsBytes(bodyBytes);
        final headers = <String, List<String>>{};
        response.headers.forEach((name, values) => headers[name] = values);
        await cachedJsonFile.writeAsString(jsonEncode(headers));

        // print(jsonEncode(headers));
        // print(response.headers['content-type'].runtimeType);
        // print('---');

        return (bodyBytes, headers['content-type']!.first);
      } else {
        // Try download image without archive.org URL part.
        final request = await client.getUrl(
          Uri.parse(
            PathUtils.getPathWithoutArchiveOrg(uri.toString()),
          ),
        );
        final response = await request.close();

        if (response.statusCode == 200) {
          final bodyBytes = Uint8List.fromList(<int>[
            for (final bytes in await response.toList()) ...bytes,
          ]);
          await cachedFile.writeAsBytes(bodyBytes);
          final headers = <String, List<String>>{};
          response.headers.forEach((name, values) => headers[name] = values);
          await cachedJsonFile.writeAsString(jsonEncode(headers));

          return (bodyBytes, headers['content-type']!.first);
        }
      }
      break;
    } on http.ClientException {
      await Future<void>.delayed(const Duration(minutes: 1));
    } on SocketException {
      return (null, '');
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
    attemptCount++;
  }

  return (null, '');
}
