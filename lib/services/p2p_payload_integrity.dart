import 'dart:convert';
import 'dart:typed_data';

/// SHA-256 implementation in pure Dart (zero external dependencies).
/// Compliant with FIPS 180-4 standard specification.
class AppSha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;
  static int _ch(int x, int y, int z) => ((x & y) ^ (~x & z)) & 0xFFFFFFFF;
  static int _maj(int x, int y, int z) => ((x & y) ^ (x & z) ^ (y & z)) & 0xFFFFFFFF;
  static int _sigma0(int x) => (_rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22)) & 0xFFFFFFFF;
  static int _sigma1(int x) => (_rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25)) & 0xFFFFFFFF;
  static int _gamma0(int x) => (_rotr(x, 7) ^ _rotr(x, 18) ^ (x >>> 3)) & 0xFFFFFFFF;
  static int _gamma1(int x) => (_rotr(x, 17) ^ _rotr(x, 19) ^ (x >>> 10)) & 0xFFFFFFFF;

  static String hashString(String input) {
    List<int> bytes = utf8.encode(input);
    return hashBytes(bytes);
  }

  static String hashBytes(List<int> bytes) {
    int bitLength = bytes.length * 8;
    int padLen = (56 - (bytes.length + 1) % 64) % 64;
    if (padLen < 0) padLen += 64;

    Uint8List padded = Uint8List(bytes.length + 1 + padLen + 8);
    padded.setRange(0, bytes.length, bytes);
    padded[bytes.length] = 0x80;
    ByteData.view(padded.buffer).setUint64(padded.length - 8, bitLength, Endian.big);

    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    Uint32List w = Uint32List(64);
    ByteData view = ByteData.view(padded.buffer);

    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = view.getUint32(chunk + i * 4, Endian.big);
      }
      for (int i = 16; i < 64; i++) {
        int s0 = _gamma0(w[i - 15]);
        int s1 = _gamma1(w[i - 2]);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int i = 0; i < 64; i++) {
        int s1 = _sigma1(e);
        int ch = _ch(e, f, g);
        int temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
        int s0 = _sigma0(a);
        int maj = _maj(a, b, c);
        int temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    ByteData out = ByteData(32);
    out.setUint32(0, h0, Endian.big);
    out.setUint32(4, h1, Endian.big);
    out.setUint32(8, h2, Endian.big);
    out.setUint32(12, h3, Endian.big);
    out.setUint32(16, h4, Endian.big);
    out.setUint32(20, h5, Endian.big);
    out.setUint32(24, h6, Endian.big);
    out.setUint32(28, h7, Endian.big);

    StringBuffer sb = StringBuffer();
    for (int i = 0; i < 32; i++) {
      sb.write(out.getUint8(i).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

/// Lightweight, deterministic application-layer integrity check for P2P payloads.
/// Provides message authentication, canonical ordering, and fail-safe validation.
class P2PPayloadIntegrity {
  static const String appSecretSalt = 'VITA_RESQ_P2P_INTEGRITY_SALT_V1';
  static const String integrityField = '_integrity';
  static const String versionField = '_integrityVersion';
  static const int currentVersion = 1;

  /// Generates canonical string representation for hashing across keys
  static String canonicalize(Map<String, dynamic> payload) {
    final sortedKeys = payload.keys.where((k) => k != integrityField).toList()..sort();
    final buffer = StringBuffer();
    buffer.write(appSecretSalt);
    buffer.write('|');
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final val = payload[key];
      buffer.write('$key=');
      if (val is Map) {
        buffer.write(canonicalize(Map<String, dynamic>.from(val)));
      } else {
        buffer.write(val?.toString() ?? 'null');
      }
      if (i < sortedKeys.length - 1) buffer.write(';');
    }
    return buffer.toString();
  }

  /// Compute integrity hash for a payload map
  static String computeHash(Map<String, dynamic> payload) {
    final canonical = canonicalize(payload);
    return AppSha256.hashString(canonical);
  }

  /// Sign payload by injecting _integrity and _integrityVersion
  static Map<String, dynamic> signPayload(Map<String, dynamic> payload) {
    final copy = Map<String, dynamic>.from(payload);
    copy[versionField] = currentVersion;
    copy[integrityField] = computeHash(copy);
    return copy;
  }

  /// Verify integrity of an incoming payload map.
  /// Fails safely if:
  /// - Missing eventType, emergencyId, or timestamp
  /// - Missing _integrity field
  /// - Computed hash does not match _integrity
  static bool verifyPayload(dynamic rawData) {
    if (rawData is! Map<String, dynamic>) {
      return false;
    }

    final String? integrityToken = rawData[integrityField]?.toString();
    if (integrityToken == null || integrityToken.isEmpty) {
      return false;
    }

    final String? eventType = rawData['eventType']?.toString();
    if (eventType == null || eventType.isEmpty) {
      return false;
    }

    final String? emergencyId = rawData['emergencyId']?.toString();
    if (emergencyId == null || emergencyId.isEmpty) {
      return false;
    }

    final dynamic timestamp = rawData['timestamp'];
    if (timestamp == null || (timestamp is! num) || timestamp <= 0) {
      return false;
    }

    final expectedHash = computeHash(rawData);
    return constantTimeEquals(expectedHash, integrityToken);
  }

  /// Constant-time string comparison to prevent timing side channels
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Safely parse and verify raw incoming bytes from Nearby Connections.
  /// Returns validated Map<String, dynamic> or null on any error / tampering.
  static Map<String, dynamic>? parseAndVerifyBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final decodedString = utf8.decode(bytes);
      return parseAndVerifyString(decodedString);
    } catch (_) {
      return null;
    }
  }

  /// Safely parse and verify JSON string.
  /// Returns validated Map<String, dynamic> or null on any error / tampering.
  static Map<String, dynamic>? parseAndVerifyString(String rawJson) {
    try {
      final dynamic parsed = jsonDecode(rawJson);
      if (parsed is! Map<String, dynamic>) return null;
      if (!verifyPayload(parsed)) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }
}
