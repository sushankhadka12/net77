import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract final class WebPolicy {
  static final home = Uri.parse('https://net77.cc/');
  // Top-level navigation only. Third-party video/CDN frames remain available.
  static const trustedHosts = ['net77.cc'];

  // Authentication is separate from advertising. These hosts are allowed
  // even when Ads are OFF so sign-in is not mistaken for an ad redirect.
  static const authHosts = ['accounts.google.com'];
  static const adHosts = [
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'adsterra.com',
    'exoclick.com',
    'exosrv.com',
    'trafficjunky.net',
    'juicyads.com',
    'adnxs.com',
  ];
  static bool _matches(String host, String domain) =>
      host == domain || host.endsWith('.$domain');
  static bool isAd(Uri uri) =>
      adHosts.any((host) => _matches(uri.host.toLowerCase(), host));

  static bool isAuth(Uri uri) =>
      authHosts.any((host) => _matches(uri.host.toLowerCase(), host));
  static bool allowsNavigation(
    Uri? uri, {
    bool isMainFrame = true,
    bool blockAds = true,
  }) {
    if (uri == null) return false;
    if (!isMainFrame &&
        (uri.toString() == 'about:blank' || uri.scheme == 'blob')) {
      return true;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if (blockAds && isAd(uri)) return false;
    if (!isMainFrame) return true;

    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;

    final host = uri.host.toLowerCase();
    return trustedHosts.any((domain) => _matches(host, domain)) ||
        authHosts.any((domain) => _matches(host, domain));
  }

  // Compatible with WKContentRuleList's restricted regular expression syntax.
  static String get adUrlPattern =>
      '^https?://([a-z0-9-]+\\.)*(${adHosts.map((h) => h.replaceAll('.', r'\.')).join('|')})(:[0-9]+)?/';
  static List<ContentBlocker> get contentBlockers => [
    ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: adUrlPattern,
        urlFilterIsCaseSensitive: false,
      ),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
  ];
  static String get pageScript =>
      '''
(() => {
  'use strict';
  if (window.__net77Protection) return;
  window.__net77Protection = true;
  const trusted = ${jsonEncode(trustedHosts)};
  const auth = ${jsonEncode(authHosts)};
  const ads = ${jsonEncode(adHosts)};
  const matches = (host, domain) => host === domain || host.endsWith('.' + domain);
  const isTrusted = url => url.protocol === 'https:' && !url.username && !url.password && (trusted.some(d => matches(url.hostname, d)) || auth.some(d => matches(url.hostname, d)));
  // Native onCreateWindow remains the final guard if a page replaces this shim.
  try { Object.defineProperty(window, 'open', { value: () => null, writable: false, configurable: false }); } catch (_) {}
  document.addEventListener('click', event => {
    const anchor = event.composedPath().find(el => el instanceof HTMLAnchorElement);
    if (!anchor) return;
    let url;
    try { url = new URL(anchor.href, location.href); } catch (_) { return; }
    const target = (anchor.target || document.querySelector('base[target]')?.target || '').toLowerCase();
    const newWindow = target && !['_self', '_top', '_parent'].includes(target);
    const leavesFrame = window === window.top || target === '_top' || target === '_parent';
    if (newWindow || (leavesFrame && !isTrusted(url)) || ads.some(d => matches(url.hostname, d))) {
      event.preventDefault();
      event.stopImmediatePropagation();
      // Normal trusted target=_blank links stay in the current view.
      if (newWindow && isTrusted(url) && event.isTrusted) location.assign(url.href);
    }
  }, true);

})();
''';
}
