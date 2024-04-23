import 'package:dart_docs_website_tools/pkg/dart_docs_shared/extensions/uri.dart';
import 'package:path/path.dart' as p;

///
class PathUtils {
  /// Remove web.archive.org part. Ex.:
  ///   from: https://web.archive.org/web/20231118115033/https://www.typescriptlang.org/docs/
  ///   to: https://www.typescriptlang.org/docs/
  /// Or:
  ///   from: /web/20231118115033/https://www.typescriptlang.org/docs/
  ///   to: https://www.typescriptlang.org/docs/
  static String getPathWithoutArchiveOrg(String path) {
    if (!path.contains('/web/20')) return path;

    // Note: '/https://' is mandatory because URL like
    // https://web.archive.org/web/20231018224739/https://nextjs.org/docs/app/api-reference/next-config-js/httpAgentOptions
    // can generate an bug with just '/http'.

    var pathVal = path;
    var idxOfHttp = path.indexOf('/https://');
    // Note: some links has the archive.org two times, so it's using a while loop.
    while (idxOfHttp != -1) {
      pathVal = pathVal.substring(idxOfHttp + 1);
      idxOfHttp = pathVal.indexOf('/https://');
    }
    return pathVal;
  }

  ///
  static String getCleanWebsiteRootRelativePath({
    /// Path of the link or resource on the page. Path to be cleaned.
    required String pathToConvert,

    /// Clean website URL. Ex.: example.com
    required String websiteDomain,

    /// Path of the page where [pathToConvert] was found.
    required String parentPagePath,

    /// Remove query part. Ex.: ?par1=val1&par2=val2
    bool removeQueryPart = false,

    /// Remove fragment part. Ex.: #the-title
    bool removeFragmentPart = false,

    /// Remove trailing slash and/or path extension.
    bool removePathExtension = false,
  }) {
    final websiteUrl = 'https://$websiteDomain';

    // Remove web.archive.org part.
    var path = PathUtils.getPathWithoutArchiveOrg(pathToConvert);

    // Remove the authority part. Ex.: https://example.com/foo -> /foo.
    if (path.startsWith(websiteUrl)) path = path.substring(websiteUrl.length);

    // Temporally remove the fragment part.
    var fragmentPart = '';
    if (path.contains('#')) {
      final charIdx = path.indexOf('#');
      fragmentPart = path.substring(charIdx);
      path = path.substring(0, charIdx);
    }

    // Temporally remove the query part.
    var queryPart = '';
    if (path.contains('?')) {
      final charIdx = path.indexOf('?');
      queryPart = path.substring(charIdx);
      path = path.substring(0, charIdx);
    }

    // Convert local relative path to root relative path. Ex.: 'something' to '/foo/bar/something'.
    if (!path.startsWith('/') && parentPagePath.isNotEmpty) {
      // Recursively get a clean parent page path.
      parentPagePath = getCleanWebsiteRootRelativePath(
        pathToConvert: parentPagePath,
        websiteDomain: websiteDomain,
        parentPagePath: '', // Irrelevant in this case because all needed data is in pathToConvert.
        removePathExtension: true,
        removeQueryPart: true,
        removeFragmentPart: true,
      );

      if (path.trim().isEmpty) {
        // Ex.: for hrefs like '#something'
        path = parentPagePath;
      } else {
        path = p.join(p.dirname(parentPagePath), path);
      }
    }

    // Remove trailing slash and/or path extension.
    if (removePathExtension) {
      if (path.endsWith('/')) path = path.substring(0, path.length - 1);
      final extension = p.extension(path);
      if (extension.isNotEmpty) path = path.substring(0, path.length - extension.length);
    }

    // Root path is empty here.
    if (path.isEmpty) path = '/';

    // Normalize before restore the query and fragment parts.
    path = p.normalize(path);

    // Restore query part.
    if (!removeQueryPart) path = '$path$queryPart';
    // Restore fragment part.
    if (!removeFragmentPart) path = '$path$fragmentPart';

    return path;
  }

  ///
  static String getStaticPath(
    String sourceUrl,
    String websiteDomain,
  ) {
    final uri = Uri.parse(sourceUrl);

    if (!uri.hasFilename) return p.join(uri.path, 'index.html');

    return uri.path;
  }

  ///
  static String getCleanImgPath(
    String imgSrc,
    String websiteDomain,
    String pageRootRelativePathOrUrl,
  ) {
    late String imgPath;

    // For Next.js images.
    if (imgSrc.contains('/_next/image?')) {
      final url = Uri.parse(
        imgSrc.substring(imgSrc.indexOf('/_next/image?')),
      ).queryParameters['url'];
      // print('URL: $url');
      imgPath = url ?? imgSrc;
    } else {
      imgPath = PathUtils.getCleanWebsiteRootRelativePath(
        pathToConvert: imgSrc,
        websiteDomain: websiteDomain,
        parentPagePath: pageRootRelativePathOrUrl,
        removeQueryPart: true,
        removeFragmentPart: true,
      );
    }

    // Check for external paths.
    // If imgPath still starts with 'https://' then this is an external image path.
    // Ex. (on _next/...): https://assets.vercel.com/image/upload/front/nextjs/spheres-light.png
    if (imgPath.startsWith('https://') && imgPath.length > 8) {
      imgPath = '/external/${imgPath.substring(8)}';
    }

    // Check for external paths.
    // If imgPath still contains '/http' then this is an external image path.
    // Ex.: /docs/handbook/release-notes/https:/raw.githubusercontent.com/wiki/Mi..../image.png
    if (imgPath.contains('/http')) {
      imgPath = '/external/${imgPath.substring(imgPath.indexOf(':/') + 2)}';
    }

    return imgPath;
  }
}
