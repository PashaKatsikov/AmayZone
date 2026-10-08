import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/palette.dart';
import '../ui/metal.dart';

/// In-app browser for the privacy policy and support pages.
///
/// Pages are rendered on a white canvas with a stock Chrome user agent so they
/// look the same as in Chrome. In particular the view is never transparent:
/// a page that doesn't paint its own background would otherwise show our dark
/// scaffold through it, giving dark text on a dark background.
class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigation,
        onPageStarted: (_) {
          if (mounted) setState(() => _failed = false);
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            if (mounted) setState(() => _failed = true);
          }
        },
      ));
    _configure();
  }

  Future<void> _configure() async {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMixedContentMode(MixedContentMode.compatibilityMode);
      await AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
          .setAcceptThirdPartyCookies(platform, true);
    }
    // The embedded WebView announces itself with "; wv" and "Version/4.0".
    // Some pages key their layout off that, so present the Chrome string.
    final ua = await _controller.getUserAgent();
    if (ua != null) {
      await _controller.setUserAgent(ua.replaceFirst('; wv)', ')').replaceFirst('Version/4.0 ', ''));
    }
    await _controller.loadRequest(Uri.parse(widget.url));
    if (mounted) setState(() => _ready = true);
  }

  Future<NavigationDecision> _onNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about' || uri.scheme == 'data') {
      return NavigationDecision.navigate;
    }
    // mailto:, tel: and friends are handed over to the system.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return NavigationDecision.prevent;
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Palette.ink,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: Column(
            children: [
              _Header(title: widget.title, onClose: () => Navigator.of(context).pop(), progress: _progress),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Stack(
                    children: [
                      if (_ready) WebViewWidget(controller: _controller),
                      if (_failed) _ErrorPane(onRetry: _retry),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose, required this.progress});

  final String title;
  final VoidCallback onClose;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: Palette.ink,
      padding: EdgeInsets.only(top: top),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Palette.amber, size: 28),
                  tooltip: 'Close',
                ),
                Expanded(
                  child: Text(title, style: Fonts.title(20, color: Palette.amber)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 3,
            child: progress > 0 && progress < 100
                ? LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.transparent,
                    color: Palette.ember,
                    minHeight: 3,
                  )
                : const ColoredBox(color: Palette.rust),
          ),
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Can\'t load the page', style: Fonts.title(24, color: Palette.amber)),
          const SizedBox(height: 10),
          const Text(
            'Check your internet connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.cream, fontSize: 15),
          ),
          const SizedBox(height: 22),
          PlateButton(label: 'RETRY', width: 200, onTap: onRetry),
        ],
      ),
    );
  }
}
