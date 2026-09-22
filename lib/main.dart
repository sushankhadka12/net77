import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'web_policy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }
  runApp(const Net77App());
}

class Net77App extends StatelessWidget {
  const Net77App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NET77',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE43D51),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF101114),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF101114)),
      useMaterial3: true,
    ),
    home: const BrowserScreen(),
  );
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _canGoBack = false, _fullscreen = false, _expanded = false;
  bool _adsEnabled = true;
  String? _error;
  int _blocked = 0, _generation = 0;
  Uri _lastPage = WebPolicy.home;
  bool get _mobile =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);

  Future<void> _syncHistory() async {
    final back = await _controller?.canGoBack() ?? false;
    if (mounted) setState(() => _canGoBack = back);
  }

  void _recordBlocked() {
    if (mounted) setState(() => _blocked++);
  }

  void _setAdsEnabled(bool value) {
    if (_adsEnabled == value) return;
    setState(() {
      _adsEnabled = value;
      _controller = null;
      _generation++;
      _error = null;
      _progress = 0;
      _canGoBack = false;
    });
  }

  void _updateSystemUI() {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        _fullscreen || _expanded
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      ),
    );
  }

  void _setFullscreen(bool value) {
    if (!mounted) return;
    setState(() => _fullscreen = value);
    _updateSystemUI();
  }

  void _expand(bool value) {
    setState(() => _expanded = value);
    _updateSystemUI();
  }

  Future<void> _back() async {
    if (_fullscreen) {
      await _controller?.evaluateJavascript(
        source: '''
        (() => {
          if (document.fullscreenElement) document.exitFullscreen();
          else if (document.webkitFullscreenElement) document.webkitExitFullscreen();
          document.querySelectorAll('video').forEach(v => {
            if (v.webkitDisplayingFullscreen && v.webkitExitFullscreen) v.webkitExitFullscreen();
          });
        })();
      ''',
      );
    } else if (_expanded) {
      _expand(false);
    } else if (await _controller?.canGoBack() ?? false) {
      await _controller?.goBack();
      await _syncHistory();
    }
  }

  Future<void> _home() async {
    setState(() => _error = null);
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(WebPolicy.home.toString())),
    );
  }

  void _retry() {
    // Recreating the native view also recovers a terminated renderer.
    setState(() {
      _controller = null;
      _generation++;
      _error = null;
      _progress = 0;
      _canGoBack = false;
    });
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _progress = 1;
      });
    }
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Widget _webView() => InAppWebView(
    key: ValueKey(_generation),
    initialUrlRequest: URLRequest(url: WebUri(_lastPage.toString())),
    initialSettings: InAppWebViewSettings(
      useShouldOverrideUrlLoading: true,
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowsAirPlayForMediaPlayback: true,
      iframeAllowFullscreen: true,
      hardwareAcceleration: true,
      useHybridComposition: true,
      isInspectable: kDebugMode,
      useOnRenderProcessGone: true,
      contentBlockers: !_adsEnabled ? WebPolicy.contentBlockers : const [],
      regexToCancelSubFramesLoading: !_adsEnabled
          ? WebPolicy.adUrlPattern
          : null,
    ),
    initialUserScripts: UnmodifiableListView(
      !_adsEnabled
          ? [
              UserScript(
                source: WebPolicy.pageScript,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                forMainFrameOnly: false,
              ),
            ]
          : const <UserScript>[],
    ),
    onWebViewCreated: (controller) {
      if (mounted) setState(() => _controller = controller);
    },
    // Authentication popups are opened in the current WebView so that
    // Google sign-in can continue instead of leaving an unhandled child window.
    // Other popup ads still follow the Ads ON/OFF setting.
    onCreateWindow: (controller, action) async {
      final uri = action.request.url?.uriValue;

      if (uri != null && WebPolicy.isAuth(uri)) {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(uri.toString())),
        );
        return false;
      }

      if (_adsEnabled) {
        // If the popup already has a URL, open it in the current view.
        // Returning true without creating a child WebView leaves the popup
        // request waiting and can look like an endless loading page.
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri(uri.toString())),
          );
        }
        return false;
      }

      _recordBlocked();
      return false;
    },
    shouldOverrideUrlLoading: (controller, action) async {
      final allowed = WebPolicy.allowsNavigation(
        action.request.url?.uriValue,
        isMainFrame: action.isForMainFrame,
        blockAds: !_adsEnabled,
      );
      if (!allowed && !_adsEnabled) _recordBlocked();
      return allowed
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL;
    },
    onLoadStart: (controller, url) {
      if (mounted) {
        setState(() {
          _error = null;
          _progress = 0;
        });
      }
    },
    onLoadStop: (controller, url) async {
      if (mounted) setState(() => _progress = 1);
      await _syncHistory();
    },
    onUpdateVisitedHistory: (controller, url, isReload) async {
      final uri = url?.uriValue;
      if (uri != null &&
          WebPolicy.allowsNavigation(uri, blockAds: !_adsEnabled)) {
        _lastPage = uri;
      }
      await _syncHistory();
    },
    onProgressChanged: (controller, progress) {
      if (mounted) setState(() => _progress = progress / 100);
    },
    onReceivedError: (controller, request, error) {
      if (request.isForMainFrame == true) {
        _showError('Check your connection and try again.');
      }
    },
    onReceivedHttpError: (controller, request, response) {
      // Verification/login pages can use these statuses and need to remain
      // visible so the user can complete the website's normal challenge.
      if (response.statusCode == 401 || response.statusCode == 403) return;
      if (request.isForMainFrame == true) {
        _showError(
          'The website returned error ${response.statusCode}. Try again later.',
        );
      }
    },
    onRenderProcessGone: (controller, detail) =>
        _showError('The page stopped responding. Tap retry to reopen it.'),
    onWebContentProcessDidTerminate: (controller) =>
        _showError('The page stopped responding. Tap retry to reopen it.'),
    onEnterFullscreen: (controller) => _setFullscreen(true),
    onExitFullscreen: (controller) => _setFullscreen(false),
    onPermissionRequest: (controller, request) async => PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.DENY,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final expanded = _fullscreen || _expanded;
    return PopScope(
      canPop: !_canGoBack && !expanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: expanded
            ? null
            : AppBar(
                title: const Text(
                  'NET77',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Ads',
                    icon: Icon(
                      _adsEnabled ? Icons.ads_click : Icons.block,
                      color: _adsEnabled ? const Color(0xFF81D7AE) : null,
                    ),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _adsEnabled ? 'Ads are on' : 'Ads are off',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Allow ads and popups'),
                                subtitle: Text(
                                  _adsEnabled
                                      ? 'Advertising domains and popup windows are allowed.'
                                      : 'Known ads, popup windows and ad redirects are blocked.',
                                ),
                                value: _adsEnabled,
                                onChanged: (value) {
                                  Navigator.of(context).pop();
                                  _setAdsEnabled(value);
                                },
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'When ads are off, popup windows and known advertising redirects are blocked.',
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$_blocked navigation attempts blocked this session.',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Some ads served by the website itself may still appear. Use the video player’s fullscreen button for fullscreen playback.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        body: SafeArea(
          top: !expanded,
          bottom: !expanded,
          child: Stack(
            children: [
              Positioned.fill(
                child: _mobile
                    ? _webView()
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Run NET77 on an Android or iOS device.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
              if (_mobile && _progress < 1 && _error == null)
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 2,
                ),
              if (_error != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 44),
                            const SizedBox(height: 20),
                            Text(
                              'Unable to load NET77',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_expanded && !_fullscreen)
                Positioned(
                  right: 12,
                  top: MediaQuery.paddingOf(context).top + 12,
                  child: IconButton.filledTonal(
                    tooltip: 'Exit expanded view',
                    onPressed: () => _expand(false),
                    icon: const Icon(Icons.fullscreen_exit),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: expanded
            ? null
            : SafeArea(
                top: false,
                child: SizedBox(
                  height: 58,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: _canGoBack ? _back : null,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton(
                        tooltip: 'Home',
                        onPressed: _controller == null ? null : _home,
                        icon: const Icon(Icons.home_outlined),
                      ),
                      IconButton(
                        tooltip: 'Reload',
                        onPressed: _controller == null
                            ? null
                            : () {
                                if (_error != null) {
                                  _retry();
                                } else {
                                  _controller?.reload();
                                }
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: 'Expand page',
                        onPressed: _controller == null
                            ? null
                            : () => _expand(true),
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
