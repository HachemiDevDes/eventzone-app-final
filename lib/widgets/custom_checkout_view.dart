import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart'; // ignore: depend_on_referenced_packages
import 'package:chargily_pay/chargily_pay.dart';

class CustomCheckoutView extends StatefulWidget {
  final Checkout checkout;
  final VoidCallback onPaymentSuccess;
  final VoidCallback? onPaymentFailure;
  final VoidCallback? onPaymentCancel;

  const CustomCheckoutView({
    super.key,
    required this.checkout,
    required this.onPaymentSuccess,
    this.onPaymentFailure,
    this.onPaymentCancel,
  });

  @override
  State<CustomCheckoutView> createState() => _CustomCheckoutViewState();
}

class _CustomCheckoutViewState extends State<CustomCheckoutView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; SM-G991U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            
            // Intercept broken Chargily redirects or success/failure URLs
            if (url.contains('/payment/success') || 
                url.contains('/success') || 
                (widget.checkout.successUrl != null && url.startsWith(widget.checkout.successUrl!))) {
              widget.onPaymentSuccess();
              return NavigationDecision.prevent;
            }

            if (url.contains('/payment/failure') || url.contains('/failure') || url.contains('/canceled') ||
                (widget.checkout.failureUrl != null && url.startsWith(widget.checkout.failureUrl!))) {
              if (widget.onPaymentFailure != null) {
                widget.onPaymentFailure!();
              }
              return NavigationDecision.prevent;
            }

            // Upgrade cleartext HTTP to HTTPS for the broken .dz domain
            if (url.startsWith('http://pay.chargily.dz')) {
              final newUrl = url.replaceFirst('http://pay.chargily.dz', 'https://pay.chargily.net');
              _controller.loadRequest(Uri.parse(newUrl));
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkout.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Secure Payment"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (widget.onPaymentCancel != null) {
              widget.onPaymentCancel!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
