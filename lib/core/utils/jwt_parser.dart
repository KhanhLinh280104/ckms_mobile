import 'dart:convert';

class JwtParser {
  /// Parses the payload of a JWT token and returns it as a Map.
  /// Returns null if parsing fails.
  static Map<String, dynamic>? parse(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payloadPart = parts[1];
      // Normalize base64url to base64
      var normalized = payloadPart.replaceAll('-', '+').replaceAll('_', '/');
      
      // Pad with '=' if necessary
      switch (normalized.length % 4) {
        case 0:
          break;
        case 2:
          normalized += '==';
          break;
        case 3:
          normalized += '=';
          break;
        default:
          return null;
      }

      final decodedBytes = base64Decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
