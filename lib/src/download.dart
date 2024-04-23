import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_docs_website_tools/src/utils/download_file.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

///
class RemotePageResource {
  ///
  const RemotePageResource({
    required this.url,
    required this.type,
    required this.content,
  });

  ///
  final String url;

  ///
  final String type;

  ///
  final Uint8List content;
}

/// Download pages and all their resources without editing anything.
class SourceDownload {
  ///
  Future<(String, String, List<RemotePageResource>)> downloadFullPage(
    String url,

    /// Space name for System TEMP directory.
    /// Ex.: 'esdocu' for '/tmp/esdocu' or 'esdocu/tech' for '/tmp/esdocu/tech'.
    String tempDirSpaceName,
  ) async {
    var pageContent = '';
    var pageTitle = '';
    final resources = <RemotePageResource>[];

    if (!url.startsWith('http') && !url.startsWith('//')) {
      return (pageContent, pageTitle, resources);
    }

    final uri = Uri.parse(url);

    final (bytes, _) = await downloadFile(uri, tempDirSpaceName);
    if (bytes == null) return (pageContent, pageTitle, resources);

    final html = utf8.decode(bytes);
    final document = parse(html);
    if (document.body == null) return (pageContent, pageTitle, resources);

    pageContent = document.outerHtml;
    pageTitle = document.head?.querySelector('title')?.text ?? '';

    // Download all resources.
    resources.addAll(
      await _downloadPageResources(
        document: document,
        pageUrl: url,
        tempDirSpaceName: tempDirSpaceName,
      ),
    );

    return (pageContent, pageTitle, resources);
  }

  /// Download all page resources: images, js, css, etc.
  Future<List<RemotePageResource>> _downloadPageResources({
    required Document document,
    required String pageUrl,

    /// Space name for System TEMP directory.
    /// Ex.: 'esdocu' for '/tmp/esdocu' or 'esdocu/tech' for '/tmp/esdocu/tech'.
    required String tempDirSpaceName,
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

      // print('--- LINK: ${link.attributes['href']!}');
      resourceUrls.add(link.attributes['href']!);
    }

    final resources = <RemotePageResource>[];
    final websiteDomain = Uri.parse(pageUrl).host;

    // Download all resources.
    for (final resourceUrl in resourceUrls) {
      // Skip Archive.org Wayback toolbar resources.
      if (resourceUrl.contains('web-static.archive.org')) continue;

      if (resourceUrl.endsWith('dsn.algolia.net')) continue;

      final remoteUrl = _completeRemoteSourcePath(resourceUrl, websiteDomain);
      final remoteSourceUri = Uri.parse(remoteUrl);

      if (remoteSourceUri.path.isEmpty || remoteSourceUri.path == '/') continue;

      final (resourceBytes, contentType) = await downloadFile(remoteSourceUri, tempDirSpaceName);

      if (resourceBytes != null) {
        resources.add(
          RemotePageResource(
            url: remoteUrl,
            type: contentType.split(';').first.trim(),
            content: resourceBytes,
          ),
        );
      }
    }

    return resources;
  }

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
