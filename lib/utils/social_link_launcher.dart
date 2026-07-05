import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchSocialLink(BuildContext context, String platform, String value) async {
  if (value.trim().isEmpty) return;

  final lowerPlatform = platform.toLowerCase().trim();
  String urlString = value.trim();

  // Map platform to correct URI scheme
  switch (lowerPlatform) {
    case 'email':
    case 'work':
    case 'mail':
      urlString = 'mailto:$urlString';
      break;
    case 'phone':
    case 'mobile':
    case 'cell':
      urlString = 'tel:$urlString';
      break;
    case 'whatsapp':
      final digits = urlString.replaceAll(RegExp(r'\D'), '');
      urlString = 'https://wa.me/$digits';
      break;
    case 'linkedin':
      if (!urlString.contains('linkedin.com')) {
        urlString = 'https://linkedin.com/in/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'github':
      if (!urlString.contains('github.com')) {
        urlString = 'https://github.com/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'twitter':
    case 'x':
      if (!urlString.contains('x.com') && !urlString.contains('twitter.com')) {
        urlString = 'https://x.com/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'instagram':
      if (!urlString.contains('instagram.com')) {
        urlString = 'https://instagram.com/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'facebook':
      if (!urlString.contains('facebook.com')) {
        urlString = 'https://facebook.com/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'telegram':
      final user = urlString.startsWith('@') ? urlString.substring(1) : urlString;
      urlString = 'https://t.me/$user';
      break;
    case 'youtube':
      if (!urlString.contains('youtube.com') && !urlString.contains('youtu.be')) {
        urlString = 'https://youtube.com/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'tiktok':
      if (!urlString.contains('tiktok.com')) {
        final user = urlString.startsWith('@') ? urlString : '@$urlString';
        urlString = 'https://tiktok.com/$user';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'behance':
      if (!urlString.contains('behance.net')) {
        urlString = 'https://behance.net/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'dribbble':
      if (!urlString.contains('dribbble.com')) {
        urlString = 'https://dribbble.com/$urlString';
      } else if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
    case 'website':
    case 'link':
    default:
      if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      break;
  }

  try {
    final uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link')),
        );
      }
    }
  } catch (e) {
    debugPrint('Could not launch $urlString: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link. Check the address and try again.'),
        ),
      );
    }
  }
}
