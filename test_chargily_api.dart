import 'package:chargily_pay/chargily_pay.dart';

void main() async {
  try {
    final client = ChargilyClient(
      ChargilyConfig.live(apiKey: 'live_sk_hibOu2wchwCnTsCJuZcdlv5mOH1NBXMNFNrktGtX'),
    );

    final request = CreateCheckoutRequest(
      amount: 2000,
      currency: 'dzd',
      successUrl: 'https://pay.chargily.net/test/success',
      failureUrl: 'https://pay.chargily.net/test/failure',
      locale: 'en',
    );

    final checkout = await client.createCheckout(request);
    print('Success: ${checkout.checkoutUrl}');
  } catch (e) {
    print('Failed with error: $e');
  }
}
