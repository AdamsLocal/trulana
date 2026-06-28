import 'dart:convert';

class WatermarkEngine {
  WatermarkEngine._();
  static final WatermarkEngine instance = WatermarkEngine._();

  // Zero-Width Non-Joiner (represents '0')
  static const String _zwnj = '\u200C';
  // Zero-Width Joiner (represents '1')
  static const String _zwj = '\u200D';

  /// Injects an invisible, traceable payload into a standard text string.
  String injectHologram(String rawText, String traceId) {
    // 1. Convert the traceId (like an Agent ID or Transaction ID) into binary
    final List<int> bytes = utf8.encode(traceId);
    final String binaryString = bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join('');

    // 2. Map the binary string to our invisible zero-width characters
    final StringBuffer invisibleWatermark = StringBuffer();
    for (int i = 0; i < binaryString.length; i++) {
      if (binaryString[i] == '0') {
        invisibleWatermark.write(_zwnj);
      } else {
        invisibleWatermark.write(_zwj);
      }
    }

    // 3. Append the invisible watermark to the end of the visible text.
    // To a human or standard parser, it looks completely normal.
    return rawText + invisibleWatermark.toString();
  }

  /// Extracts and decodes the invisible payload from a leaked string.
  String extractHologram(String watermarkedText) {
    final StringBuffer binaryString = StringBuffer();
    
    // Scan the string for our specific zero-width characters
    for (int i = 0; i < watermarkedText.length; i++) {
      final char = watermarkedText[i];
      if (char == _zwnj) {
        binaryString.write('0');
      } else if (char == _zwj) {
        binaryString.write('1');
      }
    }

    if (binaryString.isEmpty) return 'No watermark detected.';

    // Convert the extracted binary back into the original trace string
    try {
      final String binStr = binaryString.toString();
      final List<int> decodedBytes = [];
      
      for (int i = 0; i < binStr.length; i += 8) {
        if (i + 8 <= binStr.length) {
          final String byteStr = binStr.substring(i, i + 8);
          decodedBytes.add(int.parse(byteStr, radix: 2));
        }
      }
      return utf8.decode(decodedBytes);
    } catch (e) {
      return 'Corrupted watermark trace.';
    }
  }
}
