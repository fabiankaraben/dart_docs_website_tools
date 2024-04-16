import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/path.dart';
import 'package:dart_docs_website_tools/src/utils/download_file.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

///
class SourceDownload {
  ///
  Future<(String, Map<String, Uint8List>)> downloadFullPage(String url) async {
    var pageContent = '';
    final resources = <String, Uint8List>{};

    if (!url.startsWith('http') && !url.startsWith('//')) return (pageContent, resources);

    final uri = Uri.parse(url);

    final bytes = await downloadFile(uri);
    if (bytes == null) return (pageContent, resources);

    final html = utf8.decode(bytes);
    final document = parse(html);
    if (document.body == null) return (pageContent, resources);
    final body = document.body!;

    pageContent = document.outerHtml;

    // for (final imgEl in body.querySelectorAll('img')) {}
    // for (final scriptEl in body.querySelectorAll('script')) {}

    return (pageContent, resources);
  }

  /// Download all page resources: images, js, css, etc.
  Future<Map<String, Uint8List>> _downloadPageResources({
    required Document document,
    required String websiteDomain,
    required String pageUrl,
  }) async {
    final resourceUrls = <String>[];

    // Find image URLs.
    for (final img in document.body!.querySelectorAll('img')) {
      final srcs = <String>[];

      if ((img.attributes['src'] ?? '').trim().isNotEmpty) {
        srcs.add(img.attributes['src']!);
      }

      // Data example:
      // /_next/image?url=https%3A%2F%2Fassets.vercel.com%2Fimage%2Fupload%2Fv1677122002%2Fnextjs%2Fshowcase%2Ftemplate-next-boilerplate.jpg&w=1920&q=75&dpl=dpl_CWCK1djc1SYko6VDJ3ubxhyTodof 1x,
      // /_next/image?url=https%3A%2F%2Fassets.vercel.com%2Fimage%2Fupload%2Fv1677122002%2Fnextjs%2Fshowcase%2Ftemplate-next-boilerplate.jpg&w=3840&q=75&dpl=dpl_CWCK1djc1SYko6VDJ3ubxhyTodof 2x
      if ((img.attributes['srcset'] ?? '').trim().isNotEmpty) {
        srcs.addAll(img.attributes['srcset']!.split(',').map((e) => e.split(' ').first));
      }

      for (final src in srcs) {
        if (src.trim().isEmpty) continue;

        // print('--- IMAGE:');
        // print('src: $src');
        resourceUrls.add(src);
      }
    }

    // Find script URLs.
    for (final script in document.querySelectorAll('script')) {
      if ((script.attributes['src'] ?? '').trim().isEmpty) continue;

      // print('--- SCRIPT:');
      resourceUrls.add(script.attributes['src']!);
    }

    // Find link URLs.
    for (final link in document.querySelectorAll('link')) {
      if ((link.attributes['href'] ?? '').trim().isEmpty) continue;

      // print('--- LINK:');
      resourceUrls.add(link.attributes['href']!);
    }

    final resources = <String, Uint8List>{};

    // Download all resources.
    for (final resourceUrl in resourceUrls) {
      // Skip Archive.org Wayback toolbar resources.
      if (resourceUrl.contains('web-static.archive.org')) continue;

      final remoteUrl = _completeRemoteSourcePath(resourceUrl, websiteDomain);

      final remoteSourceUri = Uri.parse(remoteUrl);
      // print('remoteSourceUri: $remoteSourceUri');

      final resoucePath = PathUtils.getCleanImgPath(resourceUrl, websiteDomain, pageUrl);
      // print('resoucePath: $resoucePath');

      // final file = File(
      //   p.join(
      //     intactHtmlDownloadsDir.path,
      //     'website-data-82361054',
      //     'assets',
      //     resoucePath.substring(1),
      //   ),
      // );

      // if (file.existsSync()) continue;

      final resourceBytes = await downloadFile(remoteSourceUri);

      if (resourceBytes != null) {
        // await file.parent.create(recursive: true);
        // await file.writeAsBytes(resourceContent);

        resources[resoucePath] = resourceBytes;
      }
    }

    return resources;
  }

  // Future<Uint8List?> _downloadResource({
  //   required Uri remoteUri,
  // }) async {
  //   late http.Response response;
  //   var attemptCount = 0;
  //   while (attemptCount < 50) {
  //     try {
  //       // print('Image: $remoteSourceUri');
  //       response = await http.get(remoteUri);
  //       // print('Image response code: ${response.statusCode}');

  //       if (response.statusCode == 200) {
  //         // await file.parent.create(recursive: true);
  //         // await file.writeAsBytes(response.bodyBytes);
  //         return response.bodyBytes;
  //       } else {
  //         // Try download image without archive.org URL part.
  //         // print('Image without archive.org');
  //         response = await http.get(
  //           Uri.parse(
  //             PathUtils.getPathWithoutArchiveOrg(remoteUri.toString()),
  //           ),
  //         );
  //         if (response.statusCode == 200) {
  //           // await file.parent.create(recursive: true);
  //           // await file.writeAsBytes(response.bodyBytes);
  //           return response.bodyBytes;
  //         }
  //       }
  //       break;
  //     } on http.ClientException {
  //       // print('Image ClientException');
  //       await Future<void>.delayed(const Duration(minutes: 1));
  //     } catch (e) {
  //       rethrow;
  //     }
  //     attemptCount++;
  //   }

  //   return null;
  // }

  String _completeRemoteSourcePath(String remotePath, String websiteDomain) {
    var path = remotePath;
    if (path.startsWith('/web/20')) {
      path = 'https://web.archive.org$path';
    } else if (path.startsWith('/')) {
      path = 'https://$websiteDomain$path';
    } else if (!path.startsWith('/') && !path.startsWith('http')) {
      path = 'https://$websiteDomain/$path';
    }
    return path;
  }
}
