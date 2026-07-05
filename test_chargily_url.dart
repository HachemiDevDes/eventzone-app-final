import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://pay.chargily.net/checkouts/01kwhkyb00sd7s9x09ce3pb6nc/pay');
  final res = await http.get(url);
  print('Status: ${res.statusCode}');
}
