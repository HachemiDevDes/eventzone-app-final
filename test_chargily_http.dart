import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://pay.chargily.net/api/v2/checkouts');
  final res = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer live_sk_hibOu2wchwCnTsCJuZcdlv5m0H1NBXMNFNrktGtX',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'amount': 2000,
      'currency': 'dzd',
      'success_url': 'https://pay.chargily.net/test/success',
      'failure_url': 'https://pay.chargily.net/test/failure',
      'locale': 'en'
    }),
  );

  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
}
