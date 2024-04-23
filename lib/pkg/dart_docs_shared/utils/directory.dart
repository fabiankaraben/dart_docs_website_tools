import 'dart:io';

/// Get System TEMP directory.
String getSystemTempDirectoryPath() {
  final envVars = Platform.environment;

  if (Platform.isMacOS) {
    return envVars['TMPDIR']!;
  } else if (Platform.isLinux) {
    return '/tmp';
  }
  return '';
}
