import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Inject JavaScript to hide popup elements
            _controller.runJavaScript('''
              (function() {
                const banner = document.querySelector('div[class*="banner"], .app-promo, .header-download');
                if (banner) {
                  banner.style.display = "none";
                }
              })();
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://zoom.earth'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: WebViewWidget(controller: _controller));
  }
}
