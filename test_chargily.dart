import 'package:chargily_pay/chargily_pay.dart';
void main() async {
  final client = ChargilyPay(
    apiKey: 'live_sk_hibOu2wchwCnTsCJuZcdlv5mOH1NBXMNFNrktGtX',
    isLive: true,
  );
  print(client.runtimeType);
}
