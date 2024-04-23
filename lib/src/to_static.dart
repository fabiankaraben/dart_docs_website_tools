import 'dart:io';
import 'dart:typed_data';

import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/directory.dart';
import 'package:dart_docs_website_tools/pkg/dart_docs_shared/utils/path.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:path/path.dart' as p;

/// Adapt pages to behave as static web sites, for example on a local web server:
/// - All internal URLs are set to root relative version.
/// - Editing in HTML and/or JS (sites with Next.js for example).
/// - Cleans third party code such as Archive.org Wayback bar, analytics scripts, etc.
class ToStatic {
  ///
  ToStatic({
    required this.tempDirSpaceName,
  });

  /// Space name for System TEMP directory.
  /// Ex.: 'esdocu' for '/tmp/esdocu' or 'esdocu/tech' for '/tmp/esdocu/tech'.
  final String tempDirSpaceName;

  /// Delete previous downloaded content for this website.
  Future<void> deletePreviousStaticWebsiteDirectory() async {
    final tempDirPath = getSystemTempDirectoryPath();
    final staticWebsiteDir = Directory(p.join(tempDirPath, tempDirSpaceName));
    if (staticWebsiteDir.existsSync()) await staticWebsiteDir.delete(recursive: true);
  }

  ///
  Future<String> convertHtmlFile({
    required String sourceUrl,
    required String content,
  }) async {
    final sourceUri = Uri.parse(sourceUrl);
    final websiteDomain = sourceUri.host;

    final pageRootRelativePath = sourceUri.path;

    var html = content;

    // Remove Archive.org Wayback toolbar (Part 1).
    html = _removeArchiveOrgWaybackFromRawHtml(html);

    // TEMP: this must be a Next.js plugin.
    html = html.replaceFirst(
      r'\"href\":\"/favicon.ico\"',
      r'\"href\":\"/website-data-82361054/assets/favicon.ico\"',
    );

    final document = parse(html);

    // Remove Archive.org Wayback toolbar (Part 2).
    _removeArchiveOrgWaybackFromDocument(document);

    // Clean anchors href attribute. Always website root relative paths starting with '/'.
    // for (final anchor in document.body!.querySelectorAll('a')) {
    //   if (!anchor.attributes.containsKey('href')) continue;

    //   final href = anchor.attributes['href']!;
    //   if (!href.startsWith(websiteUrl) && href.contains('http') && !href.contains(websiteUrl)) {
    //     // Externar URL in href.
    //     anchor.attributes['href'] = PathUtils.getPathWithoutArchiveOrg(anchor.attributes['href']!);
    //   } else {
    //     // Internal URL in href.
    //     anchor.attributes['href'] = PathUtils.getCleanWebsiteRootRelativePath(
    //       pathToConvert: anchor.attributes['href']!,
    //       websiteDomain: websiteDomain,
    //       parentPagePath: pageFullPath,
    //       removeQueryPart: true,
    //     );
    //   }
    // }

    // Clean images.
    for (final img in document.body!.querySelectorAll('img')) {
      if ((img.attributes['src'] ?? '').trim().isNotEmpty) {
        final imgPath = PathUtils.getCleanImgPath(
          img.attributes['src']!,
          websiteDomain,
          pageRootRelativePath,
        );
        // print('imgPath: $imgPath');

        img.attributes['src'] = '/website-data-82361054/assets$imgPath';
      }

      if ((img.attributes['srcset'] ?? '').trim().isNotEmpty) {
        img.attributes['srcset'] = img.attributes['srcset']!.split(',').map((e) {
          final srcParts = e.split(' ');
          final src = srcParts.first;
          final imgPath = PathUtils.getCleanImgPath(src, websiteDomain, pageRootRelativePath);
          return srcParts.length == 2 ? '$imgPath ${srcParts[1]}' : imgPath;
        }).join(', ');
      }
    }

    for (final script in document.querySelectorAll('script')) {
      if ((script.attributes['src'] ?? '').isEmpty) continue;

      final scriptPath = PathUtils.getCleanImgPath(
        script.attributes['src']!,
        websiteDomain,
        pageRootRelativePath,
      );

      //
      script.attributes['src'] = '/website-data-82361054/assets$scriptPath';
    }

    for (final link in document.querySelectorAll('link')) {
      if ((link.attributes['href'] ?? '').isEmpty) continue;

      final linkPath = PathUtils.getCleanImgPath(
        link.attributes['href']!,
        websiteDomain,
        pageRootRelativePath,
      );

      //
      link.attributes['href'] = '/website-data-82361054/assets$linkPath';
    }

    return document.outerHtml;
  }

  // Remove Archive.org Wayback toolbar (Part 1).
  String _removeArchiveOrgWaybackFromRawHtml(String html) {
    var cleanHtml = html;
    const startWaybakToolbarComment = '<!-- BEGIN WAYBACK TOOLBAR INSERT -->';
    const endWaybakToolbarComment = '<!-- END WAYBACK TOOLBAR INSERT -->';
    final startWaybakToolbar = html.indexOf(startWaybakToolbarComment);
    final endWaybakToolbar = html.indexOf(endWaybakToolbarComment);
    if (startWaybakToolbar != -1 && endWaybakToolbar != -1) {
      cleanHtml = [
        html.substring(0, startWaybakToolbar),
        html.substring(endWaybakToolbar + endWaybakToolbarComment.length + 1),
      ].join();
    }
    return cleanHtml;
  }

  // Remove Archive.org Wayback toolbar (Part 2).
  void _removeArchiveOrgWaybackFromDocument(Document document) {
    final archiveOrgWaybackElements = [
      ...document.querySelectorAll('script').where(
            (e) =>
                (e.attributes['src']?.contains('archive.org') ?? false) ||
                e.innerHtml.contains('RufflePlayer') ||
                e.innerHtml.contains('archive.org'),
          ),
      ...document.querySelectorAll('link').where(
            (e) => e.attributes['href']?.contains('archive.org') ?? false,
          ),
    ];
    for (final element in archiveOrgWaybackElements) {
      element.remove();
    }
  }

  ///
  Future<String> convertJsFile({
    required String sourceUrl,
    required String content,
  }) async {
    final sourceUri = Uri.parse(sourceUrl);
    final websiteDomain = sourceUri.host;
    final pageRootRelativePath = sourceUri.path;

    var js = content;

    js = js.replaceAll(
      't.path+"?url="+encodeURIComponent(n)+"&w="+r+"&q="+(i||75)+"&dpl=dpl_8ncrBb8y3emmXZbrdhdfGiLjSeHC"',
      'n',
    );

    // src:"/_next/static
    // content = content.replaceAll(
    //   'src:"/_next/static',
    //   'src:"/website-data-82361054/assets/_next/static',
    // );
    String replaceContentFunction(String input) {
      final path = PathUtils.getCleanImgPath(input, websiteDomain, pageRootRelativePath);
      return '/website-data-82361054/assets$path';
    }

    js = _replaceAll(
      originalContent: js,
      startPattern: 'src:"',
      endPattern: '"',
      replaceContentFunction: replaceContentFunction,
    );

    js = _replaceAll(
      originalContent: js,
      startPattern: 'srcDark:"',
      endPattern: '"',
      replaceContentFunction: replaceContentFunction,
    );

    js = _replaceAll(
      originalContent: js,
      startPattern: 'srcLight:"',
      endPattern: '"',
      replaceContentFunction: replaceContentFunction,
    );

    return js;
  }

  ///
  Future<String> convertCssFile({
    required String sourceUrl,
    required String content,
  }) async {
    // final sourceUri = Uri.parse(sourceUrl);
    // final websiteDomain = sourceUri.host;
    // final pageRootRelativePath = sourceUri.path;

    final css = content;

    // Save CSS file.
    // final cleanCssFile = File(
    //   intactCssFile.path.replaceFirst(
    //     intactHtmlDownloadsDir.path,
    //     cleanHtmlDownloadsDir.path,
    //   ),
    // );
    // await cleanCssFile.parent.create(recursive: true);
    // await cleanCssFile.writeAsString(content);

    return css;
  }

  ///
  String _replaceAll({
    required String originalContent,
    required String startPattern,
    required String endPattern,
    required String Function(String) replaceContentFunction,
  }) {
    final sb = StringBuffer();
    var preTextStart = 0;
    var patternStart = originalContent.indexOf(startPattern);
    while (patternStart != -1) {
      patternStart += startPattern.length; // Avoiding the [startPattern] part.
      final patternEnd = originalContent.indexOf(endPattern, patternStart);
      final patternContent = originalContent.substring(patternStart, patternEnd);

      sb.writeAll([
        originalContent.substring(preTextStart, patternStart),
        replaceContentFunction(patternContent),
      ]);

      preTextStart = patternEnd;
      patternStart = originalContent.indexOf(startPattern, patternEnd);
    }
    sb.write(originalContent.substring(preTextStart, originalContent.length));

    return sb.toString();
  }

  ///
  Future<void> saveTextFile({
    required String sourceUrl,
    required String content,
    required String websiteDomain,
  }) async {
    final staticHtmlFile = File(
      p.join(
        getSystemTempDirectoryPath(),
        tempDirSpaceName,
        PathUtils.getStaticPath(sourceUrl, websiteDomain).substring(1),
      ),
    );
    await staticHtmlFile.parent.create(recursive: true);
    await staticHtmlFile.writeAsString(content);
  }

  ///
  Future<void> saveBinaryFile({
    required String sourceUrl,
    required Uint8List content,
    required String websiteDomain,
  }) async {
    final staticFile = File(
      p.join(
        getSystemTempDirectoryPath(),
        tempDirSpaceName,
        PathUtils.getStaticPath(sourceUrl, websiteDomain).substring(1),
      ),
    );
    await staticFile.parent.create(recursive: true);
    await staticFile.writeAsBytes(content);
  }
}
