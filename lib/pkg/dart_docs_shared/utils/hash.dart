import 'package:hashlib/hashlib.dart';

///
String createChecksum(String value) {
  return sha3_512sum(value);
}
