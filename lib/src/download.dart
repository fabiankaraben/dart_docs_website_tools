import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_docs_website_tools/src/utils/download_file.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

///
class SourceDownload {
  ///
  Future<(String, String, Map<String, Uint8List>)> downloadFullPage(String url) async {
    var pageContent = '';
    var pageTitle = '';
    final resources = <String, Uint8List>{};

    if (!url.startsWith('http') && !url.startsWith('//')) {
      return (pageContent, pageTitle, resources);
    }

    final uri = Uri.parse(url);

    final bytes = await downloadFile(uri);
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
      ),
    );

    return (pageContent, pageTitle, resources);
  }

  /// Download all page resources: images, js, css, etc.
  Future<Map<String, Uint8List>> _downloadPageResources({
    required Document document,
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
    final websiteDomain = Uri.parse(pageUrl).host;

    // Download all resources.
    for (final resourceUrl in resourceUrls) {
      // Skip Archive.org Wayback toolbar resources.
      if (resourceUrl.contains('web-static.archive.org')) continue;

      if (resourceUrl.endsWith('dsn.algolia.net')) continue;

      final remoteUrl = _completeRemoteSourcePath(resourceUrl, websiteDomain);
      final remoteSourceUri = Uri.parse(remoteUrl);

      final resourceBytes = await downloadFile(remoteSourceUri);

      if (resourceBytes != null) {
        resources[remoteUrl] = resourceBytes;
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
