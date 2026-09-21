import 'dart:async';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Function to call when a profile ID is found
  Function(String profileId)? onProfileIdFound;

  void initialize() {
    // Check initial link if app was closed
    _checkInitialLink();

    // Listen to incoming links while app is open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _processUri(uri);
    });

    // Check deferred deep linking via clipboard
    _checkDeferredLinkViaClipboard();
  }

  void _checkInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _processUri(initialUri);
      }
    } catch (e) {
      debugPrint("Failed to get initial deep link: $e");
    }
  }

  void _processUri(Uri uri) async {
    // 1. Auth callback handling
    final isAuthCallback = uri.scheme == 'eventzone' && (
      uri.host.contains('callback') ||
      uri.path.contains('callback') ||
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('access_token') ||
      uri.fragment.contains('error')
    );

    if (isAuthCallback || uri.path.contains('login-callback') || uri.path.contains('oauth-callback')) {
      try {
        debugPrint("Processing deep link auth callback: $uri");
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        debugPrint("DeepLinkService: Error recovering session from URL: $e");
      }
      return;
    }

    // 2. Profile deep link handling
    if (uri.path.contains('/profile')) {
      final profileId = uri.queryParameters['id'];
      if (profileId != null && profileId.isNotEmpty) {
        if (onProfileIdFound != null) {
          onProfileIdFound!(profileId);
        }
      }
    }
  }

  Future<void> _checkDeferredLinkViaClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final text = data.text!;
        if (text.startsWith('eventzone_profile_')) {
          final profileId = text.replaceFirst('eventzone_profile_', '');
          if (profileId.isNotEmpty) {
            // Clear clipboard to avoid triggering again
            await Clipboard.setData(ClipboardData(text: ''));
            if (onProfileIdFound != null) {
              onProfileIdFound!(profileId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to check clipboard for deferred deep link: $e");
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
