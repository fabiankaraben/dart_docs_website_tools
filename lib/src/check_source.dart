import 'dart:convert';

import 'package:dart_docs_website_tools/src/utils/download_file.dart';
import 'package:html/parser.dart';

///
class SourceMenuUrls {
  ///
  Future<List<String>> getUrlsFromWebsite({
    /// Page full URL.
    required String url,

    /// CSS query selector of the each menu container.
    required List<String> menuContainerQuerySelectors,

    /// To include external hosts or subdomains.
    List<String> extraIncludedHosts = const <String>[],

    /// To ignore some root relative paths on apex domain.
    /// Ex.: '/docs/5.2/getting-started/introduction/' or '/docs/5.2/*'.
    List<String> ignoredPaths = const <String>[],
  }) async {
    if (!url.startsWith('http') && !url.startsWith('//')) return [];

    final pendingUrls = <String>[url];
    final websiteUrls = <String>{url};

    while (pendingUrls.isNotEmpty) {
      final pageUrl = pendingUrls.removeLast();
      final pageContentUrls = await getUrlsFromPage(
        url: pageUrl,
        menuContainerQuerySelectors: menuContainerQuerySelectors,
        extraIncludedHosts: extraIncludedHosts,
        ignoredPaths: ignoredPaths,
      );

      for (final pageContentUrl in pageContentUrls) {
        if (!websiteUrls.contains(pageContentUrl)) {
          pendingUrls.add(pageContentUrl);
          websiteUrls.add(pageContentUrl);
        }
      }
    }

    return websiteUrls.toList();
  }

  ///
  Future<List<String>> getUrlsFromPage({
    /// Page full URL.
    required String url,

    /// CSS query selector of the each menu container.
    required List<String> menuContainerQuerySelectors,

    /// To include external hosts or subdomains.
    List<String> extraIncludedHosts = const <String>[],

    /// To ignore some root relative paths on apex domain.
    /// Ex.: '/docs/5.2/getting-started/introduction/' or '/docs/5.2/*'.
    List<String> ignoredPaths = const <String>[],
  }) async {
    if (!url.startsWith('http') && !url.startsWith('//')) return [];

    final uri = Uri.parse(url);

    final includedHosts = <String>[
      uri.host,
      ...extraIncludedHosts,
    ];

    final bytes = await downloadFile(uri);
    if (bytes == null) return [];

    final html = utf8.decode(bytes);
    final document = parse(html);
    if (document.body == null) return [];

    final pageUrls = <String>{};
    for (final querySelector in menuContainerQuerySelectors) {
      final menuEl = document.body!.querySelector(querySelector);
      if (menuEl == null) continue;

      for (final anchorEl in menuEl.querySelectorAll('a')) {
        if ((anchorEl.attributes['href'] ?? '').trim().isEmpty) continue;

        final href = anchorEl.attributes['href']!;
        final hrefUri = Uri.parse(href);
        final isInternalUrl = hrefUri.host.isEmpty;

        for (final ignoredPath in ignoredPaths) {
          // Exact match.
          if (ignoredPath == hrefUri.path) continue;

          // Wildcard match.
          if (ignoredPath.endsWith('*') &&
              hrefUri.path.startsWith(ignoredPath.substring(0, ignoredPath.length - 1))) {
            continue;
          }
        }

        if (isInternalUrl || includedHosts.contains(hrefUri.host)) {
          pageUrls.add(href);
        }
      }
    }

    return pageUrls.toList();
  }

  ///
  List<String> toRootRelativeUrls(List<String> urls) {
    return urls;
  }
}

///
class SourcePageContent {
  ///
  static bool hasChanges(String url, String currentChecksum) {
    // to do: download remote page and compare its checksums.
    return true;
  }
}
