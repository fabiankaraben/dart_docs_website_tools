import 'dart:io';
import 'dart:typed_data';

import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/hash.dart';
import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/path.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Downloads an HTML file or resource (js/css/image) retrying if
/// necessary and checking for problematic cases.
/// With local cache so that the same file is not downloaded twice in the same day.
Future<Uint8List?> downloadFile(Uri uri) async {
  //
  // Local cached file posibility.
  //
  const cacheExpires = Duration(days: 1);

  final envVars = Platform.environment;

  late String tempDirPath;
  if (Platform.isMacOS) {
    tempDirPath = envVars['TMPDIR']!;
  } else if (Platform.isLinux) {
    tempDirPath = '/tmp';
  } else {
    return null;
  }

  final cacheDir = Directory(p.join(tempDirPath, 'esdocu'));
  if (!cacheDir.existsSync()) await cacheDir.create();

  final cachedFile = File(
    p.join(cacheDir.path, createChecksum(uri.toString())),
  );

  if (cachedFile.existsSync()) {
    if (DateTime.now().difference(cachedFile.lastModifiedSync()) > cacheExpires) {
      await cachedFile.delete();
    } else {
      print('downloadFile (cached): $uri');
      return cachedFile.readAsBytes();
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
        return bodyBytes;
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
          return bodyBytes;
        }
      }
      break;
    } on http.ClientException {
      await Future<void>.delayed(const Duration(minutes: 1));
    } on SocketException {
      return null;
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
    attemptCount++;
  }

  return null;
}
