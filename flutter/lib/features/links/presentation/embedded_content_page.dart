import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/embedded_content.dart';
import '../data/external_link_opener.dart';

class EmbeddedContentPage extends StatefulWidget {
  const EmbeddedContentPage(
      {super.key, required this.content, required this.originalUrl});
  final EmbeddedContent content;
  final String originalUrl;
  @override
  State<EmbeddedContentPage> createState() => _EmbeddedContentPageState();
}

class _EmbeddedContentPageState extends State<EmbeddedContentPage> {
  late final WebViewController _controller;
  Timer? _timeout;
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    });
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _timeout?.cancel();
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() {
              _loading = false;
              _failed = true;
            });
          }
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
            return NavigationDecision.prevent;
          }
          final h = uri.host;
          if (h == Uri.parse(widget.originalUrl).host ||
              h == 'www.youtube.com' ||
              h == 'www.facebook.com' ||
              h.endsWith('.youtube.com') ||
              h.endsWith('.facebook.com')) {
            if (uri.path.contains('login') || uri.path.contains('signin')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(widget.content.uri,
          headers: {'Referer': 'https://com.hafeza.links.trial'});
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.content.platform)),
        body: Column(children: [
          Container(
              padding: const EdgeInsets.all(12),
              child: const Text(
                  'العرض حسب سماح الموقع. لو الصفحة مش ظاهرة افتحها من الزر تحت. ماتدخلش كلمة مرورك هنا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12))),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
              child: _failed
                  ? const Center(child: Text('تعذر عرض المحتوى داخل بؤجة.'))
                  : WebViewWidget(controller: _controller)),
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                      onPressed: () async {
                        await ExternalLinkOpener().open(widget.originalUrl);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text(
                          'لو العرض مش متاح، افتح في التطبيق الأصلي')))),
        ]),
      ));
}
