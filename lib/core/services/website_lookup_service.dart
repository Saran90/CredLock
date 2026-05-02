import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class WebsiteInfo {
  final String name;
  final String url;
  final String? faviconBase64;

  const WebsiteInfo({
    required this.name,
    required this.url,
    this.faviconBase64,
  });
}

class WebsiteLookupService {
  WebsiteLookupService._();
  static final instance = WebsiteLookupService._();

  // Cache: domain → WebsiteInfo
  final Map<String, WebsiteInfo> _cache = {};

  /// Given a raw input (e.g. "google", "github.com", "https://twitter.com"),
  /// resolves the canonical URL and fetches the favicon.
  Future<WebsiteInfo?> lookup(String input) async {
    final domain = _parseDomain(input);
    if (domain == null || domain.isEmpty) return null;

    if (_cache.containsKey(domain)) return _cache[domain];

    final url = 'https://$domain';
    final favicon = await _fetchFavicon(domain);

    final info = WebsiteInfo(
      name: _prettyName(domain),
      url: url,
      faviconBase64: favicon,
    );

    _cache[domain] = info;
    return info;
  }

  /// Extracts a clean domain from any input string.
  String? _parseDomain(String input) {
    input = input.trim().toLowerCase();
    if (input.isEmpty) return null;

    // Strip protocol
    input = input
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'^www\.'), '');

    // Take only the host part (drop path/query)
    final slashIdx = input.indexOf('/');
    if (slashIdx != -1) input = input.substring(0, slashIdx);

    // If no dot, assume .com
    if (!input.contains('.')) input = '$input.com';

    return input;
  }

  /// Tries multiple favicon sources in order of reliability.
  Future<String?> _fetchFavicon(String domain) async {
    // 1. Google's favicon service (most reliable, returns 16–256px PNG)
    final googleUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';

    // 2. DuckDuckGo's favicon service (fallback)
    final ddgUrl = 'https://icons.duckduckgo.com/ip3/$domain.ico';

    // 3. Direct favicon.ico on the domain
    final directUrl = 'https://$domain/favicon.ico';

    for (final url in [googleUrl, ddgUrl, directUrl]) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 &&
            response.bodyBytes.isNotEmpty &&
            _isValidImage(response.bodyBytes)) {
          return base64Encode(response.bodyBytes);
        }
      } catch (_) {
        // Try next source
      }
    }
    return null;
  }

  /// Basic check that the bytes look like a real image (not an error page).
  bool _isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return true;
    // JPEG: FF D8
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return true;
    // ICO: 00 00 01 00
    if (bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01) return true;
    // WebP: 52 49 46 46
    if (bytes[0] == 0x52 && bytes[1] == 0x49) return true;
    return false;
  }

  /// Turns "github.com" → "GitHub", "google.com" → "Google", etc.
  String _prettyName(String domain) {
    // Strip TLD
    final parts = domain.split('.');
    final name = parts.first;
    if (name.isEmpty) return domain;
    return name[0].toUpperCase() + name.substring(1);
  }
}
