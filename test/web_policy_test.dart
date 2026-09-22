import 'package:flutter_test/flutter_test.dart';
import 'package:net77/web_policy.dart';

void main() {
  test('Allows site navigation and subdomains', () {
    for (final url in [
      'https://net77.cc/',
      'https://www.net77.cc/watch/123',
      'https://net77.cc/search?q=test',
    ]) {
      expect(WebPolicy.allowsNavigation(Uri.parse(url)), isTrue, reason: url);
    }
  });
  test('Rejects redirects, deceptive hosts and app launch URLs', () {
    for (final url in [
      'https://net77.cc.evil.test/',
      'https://evilnet77.cc/',
      'https://net77.cc@evil.test/',
      'https://user@net77.cc/',
      'http://net77.cc/',
      'intent://video',
      'javascript:alert(1)',
      'data:text/html,test',
      'https://example.com/',
      'about:blank',
    ]) {
      expect(WebPolicy.allowsNavigation(Uri.parse(url)), isFalse, reason: url);
    }
    expect(WebPolicy.allowsNavigation(null), isFalse);
  });
  test('Allows video frames but rejects known advertising frames', () {
    for (final url in [
      'https://cdn.example.org/embed/1',
      'blob:https://net77.cc/video',
      'about:blank',
    ]) {
      expect(
        WebPolicy.allowsNavigation(Uri.parse(url), isMainFrame: false),
        isTrue,
      );
    }
    for (final url in ['https://ads.doubleclick.net/ad', 'intent://ad']) {
      expect(
        WebPolicy.allowsNavigation(Uri.parse(url), isMainFrame: false),
        isFalse,
      );
    }
  });
  test('Native resource filter matches host boundaries and ports', () {
    final filter = RegExp(WebPolicy.adUrlPattern, caseSensitive: false);
    for (final host in WebPolicy.adHosts) {
      expect(filter.hasMatch('https://$host/ad.js'), isTrue);
      expect(filter.hasMatch('https://sub.$host:443/ad.js'), isTrue);
      expect(filter.hasMatch('https://$host.example.org/video'), isFalse);
    }
    expect(
      filter.hasMatch('https://net77.cc/video?url=doubleclick.net'),
      isFalse,
    );
    expect(filter.hasMatch('https://cdn.example.com/movie.m3u8'), isFalse);
  });
}
