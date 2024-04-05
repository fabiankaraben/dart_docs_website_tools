import 'dart:io';
import 'dart:typed_data';

import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/path.dart';
import 'package:hashlib/hashlib.dart';
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
    p.join(cacheDir.path, sha3_512sum(uri.toString())),
  );

  if (cachedFile.existsSync()) {
    if (DateTime.now().difference(cachedFile.lastModifiedSync()) > cacheExpires) {
      await cachedFile.delete();
    } else {
      return cachedFile.readAsBytes();
    }
  }

  //
  // Remote file.
  //

  late http.Response response;
  var attemptCount = 0;
  while (attemptCount < 50) {
    try {
      response = await http.get(uri);

      if (response.statusCode == 200) {
        await cachedFile.writeAsBytes(response.bodyBytes);
        return response.bodyBytes;
      } else {
        // Try download image without archive.org URL part.
        response = await http.get(
          Uri.parse(
            PathUtils.getPathWithoutArchiveOrg(uri.toString()),
          ),
        );
        if (response.statusCode == 200) {
          await cachedFile.writeAsBytes(response.bodyBytes);
          return response.bodyBytes;
        }
      }
      break;
    } on http.ClientException {
      await Future<void>.delayed(const Duration(minutes: 1));
    } catch (e) {
      rethrow;
    }
    attemptCount++;
  }

  return null;
}
