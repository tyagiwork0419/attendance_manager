import 'dart:convert';

class Encoder {
  static String toUtf8WithBOM(String csv) {
    final bomUtf8Csv = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    final base64CsvBytes = base64Encode(bomUtf8Csv);

    return base64CsvBytes;
  }
}
