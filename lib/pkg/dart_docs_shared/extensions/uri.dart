import 'package:mime/mime.dart';

///
extension UriExtension on Uri {
  /// Returns true if the path ends with a valid filename.
  bool get hasFilename =>
      pathSegments.isNotEmpty &&
      pathSegments.last.contains('.') &&
      (pathSegments.last.endsWith('.map') || lookupMimeType(pathSegments.last) != null);
}
