# Payment Integration Architecture

## Overview

A unified payment system supporting **Google Pay**, **Apple Pay**, and **PayPal** for booking payments, with a provider-agnostic architecture allowing easy addition of future payment methods.

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER APP                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Google Pay  │  │ Apple Pay   │  │   PayPal    │  │   Future    │    │
│  │   Button    │  │   Button    │  │   Button    │  │  Provider   │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
│         │                │                │                │            │
│         └────────────────┴────────────────┴────────────────┘            │
│                                   │                                      │
│                    ┌──────────────▼──────────────┐                      │
│                    │     PaymentService          │                      │
│                    │  (Provider Abstraction)     │                      │
│                    └──────────────┬──────────────┘                      │
└───────────────────────────────────┼─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        CLOUD FUNCTIONS                                   │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │ createPayment   │  │ processWebhook  │  │ processRefund   │         │
│  │ Intent          │  │ (per provider)  │  │                 │         │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘         │
│           │                    │                    │                   │
│           └────────────────────┴────────────────────┘                   │
│                                │                                        │
└────────────────────────────────┼────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     PAYMENT PROCESSORS                                   │
├──────────────────┬──────────────────┬───────────────────────────────────┤
│    Stripe        │    Braintree     │        PayPal                     │
│  (Google/Apple)  │   (Alternative)  │      (Direct)                     │
└──────────────────┴──────────────────┴───────────────────────────────────┘
```

---

## 2. Data Models

### Firestore Collections

```
├── payments/
│   └── {paymentId}
│
├── payment_methods/
│   └── {userId}/
│       └── methods (subcollection)
│           └── {methodId}
│
├── transactions/
│   └── {transactionId}
│
├── refunds/
│   └── {refundId}
│
├── payouts/
│   └── {payoutId}  (payments to experts)
```

### Dart Models

```dart
// lib/features/payments/data/models/payment.dart

enum PaymentProvider {
  googlePay,
  applePay,
  paypal,
  stripe,    // for card payments
  wallet,    // in-app wallet
}

enum PaymentStatus {
  pending,
  processing,
  succeeded,
  failed,
  cancelled,
  refunded,
  partiallyRefunded,
}

enum PaymentType {
  bookingPayment,
  tipPayment,
  walletTopUp,
  subscriptionPayment,
}

class Payment {
  final String id;
  final String userId;
  final String? expertId;
  final String? bookingId;
  final PaymentProvider provider;
  final PaymentType type;
  final PaymentStatus status;
  final Money amount;
  final Money? platformFee;
  final Money? expertPayout;
  final String currency;
  final String? providerPaymentId;    // Stripe/PayPal payment ID
  final String? providerCustomerId;
  final Map<String, dynamic>? metadata;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? completedAt;
}

class Money {
  final int amountInCents;  // Always store in smallest unit
  final String currency;
  
  double get amountDecimal => amountInCents / 100;
  
  factory Money.fromDecimal(double amount, String currency) {
    return Money(
      amountInCents: (amount * 100).round(),
      currency: currency,
    );
  }
}

class PaymentMethod {
  final String id;
  final String userId;
  final PaymentProvider provider;
  final PaymentMethodType type;  // card, bank, wallet
  final String? last4;
  final String? brand;           // visa, mastercard, etc.
  final String? expiryMonth;
  final String? expiryYear;
  final String? email;           // for PayPal
  final bool isDefault;
  final String? providerTokenId;
  final DateTime createdAt;
}

class Transaction {
  final String id;
  final String paymentId;
  final TransactionType type;    // charge, refund, payout
  final Money amount;
  final String status;
  final String? providerTransactionId;
  final DateTime createdAt;
}

class ExpertPayout {
  final String id;
  final String expertId;
  final List<String> paymentIds;  // aggregated payments
  final Money totalAmount;
  final Money platformFee;
  final Money netPayout;
  final PayoutStatus status;
  final String? providerPayoutId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime? paidAt;
}
```

---

## 3. Service Layer Architecture

### Abstract Payment Provider Interface

```dart
// lib/features/payments/domain/interfaces/payment_provider.dart

abstract class IPaymentProvider {
  PaymentProvider get providerType;
  
  /// Check if this provider is available on current platform
  Future<bool> isAvailable();
  
  /// Initialize the provider SDK
  Future<void> initialize();
  
  /// Create a payment intent/session
  Future<PaymentIntent> createPaymentIntent({
    required Money amount,
    required String currency,
    Map<String, dynamic>? metadata,
  });
  
  /// Process the payment with provider-specific token
  Future<PaymentResult> processPayment({
    required String paymentIntentId,
    required dynamic paymentToken,  // Provider-specific
  });
  
  /// Handle provider-specific UI (sheets, redirects)
  Future<PaymentToken?> showPaymentSheet({
    required PaymentIntent intent,
    required PaymentSheetConfig config,
  });
}
```

### Provider Implementations

```dart
// lib/features/payments/infrastructure/providers/google_pay_provider.dart

class GooglePayProvider implements IPaymentProvider {
  final Pay _payClient = Pay({
    googlePay: PaymentConfiguration.fromJsonString(googlePayConfig),
  });
  
  @override
  PaymentProvider get providerType => PaymentProvider.googlePay;
  
  @override
  Future<bool> isAvailable() async {
    return Platform.isAndroid && 
           await _payClient.userCanPay(PayProvider.google_pay);
  }
  
  @override
  Future<PaymentToken?> showPaymentSheet({
    required PaymentIntent intent,
    required PaymentSheetConfig config,
  }) async {
    final result = await _payClient.showPaymentSelector(
      PayProvider.google_pay,
      [
        PaymentItem(
          label: config.merchantName,
          amount: intent.amount.amountDecimal.toStringAsFixed(2),
          status: PaymentItemStatus.final_price,
        ),
      ],
    );
    return GooglePayToken(data: result);
  }
}

// lib/features/payments/infrastructure/providers/apple_pay_provider.dart

class ApplePayProvider implements IPaymentProvider {
  @override
  PaymentProvider get providerType => PaymentProvider.applePay;
  
  @override
  Future<bool> isAvailable() async {
    return Platform.isIOS && 
           await Stripe.instance.isApplePaySupported();
  }
  
  @override
  Future<PaymentToken?> showPaymentSheet({
    required PaymentIntent intent,
    required PaymentSheetConfig config,
  }) async {
    await Stripe.instance.presentApplePay(
      ApplePayPresentParams(
        cartItems: [
          ApplePayCartSummaryItem.immediate(
            label: config.merchantName,
            amount: intent.amount.amountDecimal.toStringAsFixed(2),
          ),
        ],
        country: config.countryCode,
        currency: intent.currency,
      ),
    );
    return ApplePayToken(confirmed: true);
  }
}

// lib/features/payments/infrastructure/providers/paypal_provider.dart

class PayPalProvider implements IPaymentProvider {
  @override
  PaymentProvider get providerType => PaymentProvider.paypal;
  
  @override
  Future<bool> isAvailable() async => true;  // Always available
  
  @override
  Future<PaymentToken?> showPaymentSheet({
    required PaymentIntent intent,
    required PaymentSheetConfig config,
  }) async {
    // Launch PayPal checkout flow
    final result = await FlutterBraintree.requestPaypalNonce(
      BraintreePayPalRequest(
        amount: intent.amount.amountDecimal.toStringAsFixed(2),
        currencyCode: intent.currency,
        displayName: config.merchantName,
      ),
    );
    return PayPalToken(nonce: result?.nonce);
  }
}
```

### Unified Payment Service

```dart
// lib/features/payments/domain/services/payment_service.dart

class PaymentService {
  final PaymentRepository _repository;
  final Map<PaymentProvider, IPaymentProvider> _providers;
  final CloudFunctionsService _cloudFunctions;
  
  PaymentService({
    required PaymentRepository repository,
    required CloudFunctionsService cloudFunctions,
  }) : _repository = repository,
       _cloudFunctions = cloudFunctions,
       _providers = {} {
    _registerProviders();
  }
  
  void _registerProviders() {
    _providers[PaymentProvider.googlePay] = GooglePayProvider();
    _providers[PaymentProvider.applePay] = ApplePayProvider();
    _providers[PaymentProvider.paypal] = PayPalProvider();
  }
  
  /// Get available payment methods for current platform
  Future<List<PaymentProvider>> getAvailableProviders() async {
    final available = <PaymentProvider>[];
    for (final entry in _providers.entries) {
      if (await entry.value.isAvailable()) {
        available.add(entry.key);
      }
    }
    return available;
  }
  
  /// Process a booking payment
  Future<Result<Payment, PaymentError>> processBookingPayment({
    required String bookingId,
    required String expertId,
    required Money amount,
    required PaymentProvider provider,
  }) async {
    try {
      // 1. Create payment intent on server
      final intent = await _cloudFunctions.call<PaymentIntent>(
        'createPaymentIntent',
        data: {
          'amount': amount.amountInCents,
          'currency': amount.currency,
          'bookingId': bookingId,
          'expertId': expertId,
          'provider': provider.name,
        },
      );
      
      // 2. Show provider payment sheet
      final providerImpl = _providers[provider]!;
      final token = await providerImpl.showPaymentSheet(
        intent: intent,
        config: PaymentSheetConfig(
          merchantName: 'GreenHive',
          countryCode: 'US',
        ),
      );
      
      if (token == null) {
        return Result.failure(PaymentError.cancelled);
      }
      
      // 3. Confirm payment on server
      final payment = await _cloudFunctions.call<Payment>(
        'confirmPayment',
        data: {
          'paymentIntentId': intent.id,
          'token': token.toJson(),
        },
      );
      
      return Result.success(payment);
    } on PaymentException catch (e) {
      return Result.failure(PaymentError.fromException(e));
    }
  }
  
  /// Request a refund
  Future<Result<Refund, PaymentError>> requestRefund({
    required String paymentId,
    required Money amount,
    required String reason,
  }) async {
    return _cloudFunctions.call<Refund>(
      'processRefund',
      data: {
        'paymentId': paymentId,
        'amount': amount.amountInCents,
        'reason': reason,
      },
    );
  }
}
```

---

## 4. Cloud Functions (Backend)

```typescript
// functions/src/payments/index.ts

import * as functions from 'firebase-functions';
import Stripe from 'stripe';
import * as paypal from '@paypal/checkout-server-sdk';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

// Platform fee percentage (e.g., 15%)
const PLATFORM_FEE_PERCENT = 15;

/**
 * Create a payment intent for booking
 */
export const createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  
  const { amount, currency, bookingId, expertId, provider } = data;
  
  // Calculate platform fee
  const platformFee = Math.round(amount * PLATFORM_FEE_PERCENT / 100);
  const expertPayout = amount - platformFee;
  
  // Get expert's Stripe Connect account (for direct payouts)
  const expertDoc = await admin.firestore().collection('experts').doc(expertId).get();
  const stripeAccountId = expertDoc.data()?.stripeAccountId;
  
  if (provider === 'googlePay' || provider === 'applePay') {
    // Create Stripe Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      payment_method_types: provider === 'applePay' ? ['card'] : ['card'],
      metadata: {
        bookingId,
        expertId,
        userId: context.auth.uid,
        platformFee: platformFee.toString(),
      },
      // For Stripe Connect - split payment
      application_fee_amount: platformFee,
      transfer_data: stripeAccountId ? {
        destination: stripeAccountId,
      } : undefined,
    });
    
    // Store pending payment
    await admin.firestore().collection('payments').doc(paymentIntent.id).set({
      id: paymentIntent.id,
      userId: context.auth.uid,
      expertId,
      bookingId,
      provider,
      status: 'pending',
      amount,
      platformFee,
      expertPayout,
      currency,
      providerPaymentId: paymentIntent.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      id: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      amount,
      currency,
    };
  }
  
  if (provider === 'paypal') {
    // Create PayPal order
    const order = await createPayPalOrder(amount, currency, bookingId);
    
    await admin.firestore().collection('payments').doc(order.id).set({
      id: order.id,
      userId: context.auth.uid,
      expertId,
      bookingId,
      provider: 'paypal',
      status: 'pending',
      amount,
      platformFee,
      expertPayout,
      currency,
      providerPaymentId: order.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      id: order.id,
      approvalUrl: order.links.find((l: any) => l.rel === 'approve')?.href,
      amount,
      currency,
    };
  }
});

/**
 * Stripe webhook handler
 */
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature']!;
  const event = stripe.webhooks.constructEvent(
    req.rawBody,
    sig,
    process.env.STRIPE_WEBHOOK_SECRET!
  );
  
  switch (event.type) {
    case 'payment_intent.succeeded':
      await handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
      break;
    case 'payment_intent.payment_failed':
      await handlePaymentFailure(event.data.object as Stripe.PaymentIntent);
      break;
    case 'charge.refunded':
      await handleRefund(event.data.object as Stripe.Charge);
      break;
  }
  
  res.json({ received: true });
});

async function handlePaymentSuccess(paymentIntent: Stripe.PaymentIntent) {
  const paymentRef = admin.firestore().collection('payments').doc(paymentIntent.id);
  
  await admin.firestore().runTransaction(async (tx) => {
    // Update payment status
    tx.update(paymentRef, {
      status: 'succeeded',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Update booking status
    const bookingId = paymentIntent.metadata.bookingId;
    if (bookingId) {
      const bookingRef = admin.firestore().collection('bookings').doc(bookingId);
      tx.update(bookingRef, {
        paymentStatus: 'paid',
        paymentId: paymentIntent.id,
      });
    }
  });
  
  // Send confirmation notifications
  await sendPaymentConfirmation(paymentIntent.metadata.userId, paymentIntent.id);
}

/**
 * Process refund
 */
export const processRefund = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  
  const { paymentId, amount, reason } = data;
  
  const paymentDoc = await admin.firestore().collection('payments').doc(paymentId).get();
  const payment = paymentDoc.data();
  
  if (!payment) throw new functions.https.HttpsError('not-found', 'Payment not found');
  
  // Verify user can request refund (owner or admin)
  if (payment.userId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot refund this payment');
  }
  
  // Process refund based on provider
  if (payment.provider === 'googlePay' || payment.provider === 'applePay') {
    const refund = await stripe.refunds.create({
      payment_intent: payment.providerPaymentId,
      amount: amount || undefined,  // Full refund if not specified
      reason: 'requested_by_customer',
    });
    
    await admin.firestore().collection('refunds').doc(refund.id).set({
      id: refund.id,
      paymentId,
      amount: refund.amount,
      reason,
      status: refund.status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return { id: refund.id, status: refund.status };
  }
  
  // PayPal refund logic...
});
```

---

## 5. Platform Configuration

### Google Pay Configuration

```json
// assets/google_pay_config.json
{
  "provider": "google_pay",
  "data": {
    "environment": "PRODUCTION",
    "apiVersion": 2,
    "apiVersionMinor": 0,
    "allowedPaymentMethods": [{
      "type": "CARD",
      "tokenizationSpecification": {
        "type": "PAYMENT_GATEWAY",
        "parameters": {
          "gateway": "stripe",
          "stripe:version": "2020-08-27",
          "stripe:publishableKey": "pk_live_xxx"
        }
      },
      "parameters": {
        "allowedCardNetworks": ["VISA", "MASTERCARD", "AMEX", "DISCOVER"],
        "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
        "billingAddressRequired": true
      }
    }],
    "merchantInfo": {
      "merchantId": "BCR2DN6T7XXXXXXX",
      "merchantName": "GreenHive"
    },
    "transactionInfo": {
      "countryCode": "US",
      "currencyCode": "USD"
    }
  }
}
```

### Apple Pay Configuration

```xml
<!-- ios/Runner/Runner.entitlements -->
<key>com.apple.developer.in-app-payments</key>
<array>
  <string>merchant.com.greenhive.app</string>
</array>
```

### Info.plist Additions

```xml
<!-- ios/Runner/Info.plist -->
<key>NSApplePayUsageDescription</key>
<string>Pay for expert consultations securely with Apple Pay</string>
```

---

## 6. UI Components

### Payment Method Selector

```dart
// lib/features/payments/presentation/widgets/payment_method_selector.dart

class PaymentMethodSelector extends StatelessWidget {
  final Money amount;
  final Function(PaymentProvider) onProviderSelected;
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentProvider>>(
      future: sl<PaymentService>().getAvailableProviders(),
      builder: (context, snapshot) {
        final providers = snapshot.data ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pay ${amount.formatted}', style: AppTypography.h3),
            const SizedBox(height: 16),
            
            // Apple Pay (iOS only)
            if (providers.contains(PaymentProvider.applePay))
              _PaymentButton(
                provider: PaymentProvider.applePay,
                child: ApplePayButton(
                  type: ApplePayButtonType.book,
                  onPressed: () => onProviderSelected(PaymentProvider.applePay),
                ),
              ),
            
            // Google Pay (Android only)
            if (providers.contains(PaymentProvider.googlePay))
              _PaymentButton(
                provider: PaymentProvider.googlePay,
                child: GooglePayButton(
                  paymentConfiguration: PaymentConfiguration.fromJsonString(
                    googlePayConfig,
                  ),
                  onPressed: () => onProviderSelected(PaymentProvider.googlePay),
                  type: GooglePayButtonType.book,
                ),
              ),
            
            // PayPal (always available)
            _PaymentButton(
              provider: PaymentProvider.paypal,
              onTap: () => onProviderSelected(PaymentProvider.paypal),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/paypal.png', height: 24),
                  const SizedBox(width: 8),
                  const Text('Pay with PayPal'),
                ],
              ),
            ),
            
            const Divider(height: 32),
            
            // Card payment option
            OutlinedButton(
              onPressed: () => onProviderSelected(PaymentProvider.stripe),
              child: const Text('Pay with Card'),
            ),
          ],
        );
      },
    );
  }
}
```

### Payment Confirmation Sheet

```dart
class PaymentConfirmationSheet extends StatelessWidget {
  final Booking booking;
  final Money amount;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Booking summary
          _BookingSummaryCard(booking: booking),
          
          const SizedBox(height: 24),
          
          // Price breakdown
          _PriceBreakdown(
            subtotal: amount,
            serviceFee: Money.fromDecimal(amount.amountDecimal * 0.05, amount.currency),
            total: Money.fromDecimal(amount.amountDecimal * 1.05, amount.currency),
          ),
          
          const SizedBox(height: 24),
          
          // Payment methods
          PaymentMethodSelector(
            amount: amount,
            onProviderSelected: (provider) async {
              final result = await sl<PaymentService>().processBookingPayment(
                bookingId: booking.id,
                expertId: booking.expertId,
                amount: amount,
                provider: provider,
              );
              
              result.when(
                success: (payment) {
                  Navigator.pop(context, payment);
                  SnackbarService.showSuccess('Payment successful!');
                },
                failure: (error) {
                  SnackbarService.showError(error.message);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
```

---

## 7. File Structure

```
lib/features/payments/
├── data/
│   ├── models/
│   │   ├── payment.dart
│   │   ├── payment_method.dart
│   │   ├── transaction.dart
│   │   ├── refund.dart
│   │   └── payout.dart
│   └── repositories/
│       └── payment_repository.dart
├── domain/
│   ├── interfaces/
│   │   └── payment_provider.dart
│   └── services/
│       ├── payment_service.dart
│       └── payout_service.dart
├── infrastructure/
│   └── providers/
│       ├── google_pay_provider.dart
│       ├── apple_pay_provider.dart
│       ├── paypal_provider.dart
│       └── stripe_provider.dart
├── presentation/
│   ├── pages/
│   │   ├── payment_page.dart
│   │   ├── payment_history_page.dart
│   │   └── payment_methods_page.dart
│   ├── view_models/
│   │   └── payment_view_model.dart
│   └── widgets/
│       ├── payment_method_selector.dart
│       ├── payment_button.dart
│       ├── price_breakdown.dart
│       └── payment_status_badge.dart
└── payments_feature.dart

functions/src/payments/
├── index.ts
├── stripe.ts
├── paypal.ts
├── webhooks.ts
├── refunds.ts
└── payouts.ts
```

---

## 8. Security Considerations

| Concern | Solution |
|---------|----------|
| **No sensitive data on client** | All payment processing happens server-side via Cloud Functions |
| **PCI Compliance** | Use Stripe/Braintree tokenization - never handle raw card data |
| **Webhook verification** | Verify signatures on all webhook endpoints |
| **Idempotency** | Use idempotency keys for all payment operations |
| **Rate limiting** | Cloud Functions rate limiting on payment endpoints |
| **Audit logging** | Log all payment events to `transactions` collection |

---

## 9. Firestore Security Rules

```javascript
// firestore.rules additions for payments

match /payments/{paymentId} {
  allow read: if request.auth.uid == resource.data.userId 
              || request.auth.uid == resource.data.expertId;
  // Only Cloud Functions can write payments
  allow write: if false;
}

match /payment_methods/{userId}/methods/{methodId} {
  allow read, write: if request.auth.uid == userId;
}

match /transactions/{transactionId} {
  allow read: if request.auth.uid == resource.data.userId 
              || request.auth.uid == resource.data.expertId;
  allow write: if false;  // Only Cloud Functions
}

match /refunds/{refundId} {
  allow read: if request.auth.uid == resource.data.userId;
  allow write: if false;  // Only Cloud Functions
}

match /payouts/{payoutId} {
  allow read: if request.auth.uid == resource.data.expertId;
  allow write: if false;  // Only Cloud Functions
}
```

---

## 10. Recommended Flutter Packages

| Package | Purpose |
|---------|---------|
| `pay` | Google Pay & Apple Pay unified API |
| `flutter_stripe` | Stripe SDK (cards, Apple Pay) |
| `flutter_braintree` | Braintree/PayPal SDK |
| `in_app_purchase` | Alternative for subscriptions |

---

## 11. Expert Payouts (Stripe Connect)

```dart
// Expert onboarding to receive payments
class ExpertPayoutService {
  /// Create Stripe Connect account for expert
  Future<String> createConnectAccount(String expertId) async {
    return _cloudFunctions.call('createConnectAccount', data: {
      'expertId': expertId,
    });
  }
  
  /// Get onboarding link for expert to complete KYC
  Future<String> getOnboardingLink(String expertId) async {
    return _cloudFunctions.call('getConnectOnboardingLink', data: {
      'expertId': expertId,
    });
  }
  
  /// Get expert's payout history
  Stream<List<ExpertPayout>> watchPayouts(String expertId) {
    return _firestore
      .collection('payouts')
      .where('expertId', isEqualTo: expertId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(ExpertPayout.fromFirestore).toList());
  }
}
```

### Expert Payout Cloud Functions

```typescript
// functions/src/payments/payouts.ts

/**
 * Create Stripe Connect account for expert
 */
export const createConnectAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  
  const { expertId } = data;
  
  // Verify the user is the expert
  if (context.auth.uid !== expertId) {
    throw new functions.https.HttpsError('permission-denied', 'Can only create account for yourself');
  }
  
  const account = await stripe.accounts.create({
    type: 'express',
    country: 'US',
    capabilities: {
      transfers: { requested: true },
    },
    metadata: {
      expertId,
    },
  });
  
  // Store account ID
  await admin.firestore().collection('experts').doc(expertId).update({
    stripeAccountId: account.id,
    stripeAccountStatus: 'pending',
  });
  
  return { accountId: account.id };
});

/**
 * Generate onboarding link for expert KYC
 */
export const getConnectOnboardingLink = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  
  const expertDoc = await admin.firestore().collection('experts').doc(context.auth.uid).get();
  const stripeAccountId = expertDoc.data()?.stripeAccountId;
  
  if (!stripeAccountId) {
    throw new functions.https.HttpsError('failed-precondition', 'No Stripe account found');
  }
  
  const accountLink = await stripe.accountLinks.create({
    account: stripeAccountId,
    refresh_url: 'https://greenhive.app/expert/payouts/refresh',
    return_url: 'https://greenhive.app/expert/payouts/complete',
    type: 'account_onboarding',
  });
  
  return { url: accountLink.url };
});

/**
 * Process weekly payouts to experts (scheduled function)
 */
export const processWeeklyPayouts = functions.pubsub
  .schedule('every monday 09:00')
  .timeZone('America/New_York')
  .onRun(async () => {
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    // Get all completed payments from last week
    const paymentsSnap = await admin.firestore()
      .collection('payments')
      .where('status', '==', 'succeeded')
      .where('completedAt', '>=', oneWeekAgo)
      .where('payoutProcessed', '==', false)
      .get();
    
    // Group by expert
    const expertPayments = new Map<string, any[]>();
    paymentsSnap.docs.forEach(doc => {
      const payment = doc.data();
      const existing = expertPayments.get(payment.expertId) || [];
      existing.push(payment);
      expertPayments.set(payment.expertId, existing);
    });
    
    // Process payout for each expert
    for (const [expertId, payments] of expertPayments) {
      await processExpertPayout(expertId, payments);
    }
  });
```

---

## 12. Integration with Booking System

```dart
// In BookingService - after booking is confirmed
Future<void> _initiatePayment(Booking booking) async {
  final expert = await _expertRepository.getExpert(booking.expertId);
  final amount = Money.fromDecimal(
    expert.hourlyRate * (booking.durationMinutes / 60),
    'USD',
  );
  
  // Show payment sheet
  final payment = await showModalBottomSheet<Payment>(
    context: context,
    builder: (_) => PaymentConfirmationSheet(
      booking: booking,
      amount: amount,
    ),
  );
  
  if (payment != null && payment.status == PaymentStatus.succeeded) {
    // Update booking with payment
    await _bookingRepository.updateBooking(
      booking.id,
      paymentId: payment.id,
      paymentStatus: 'paid',
    );
  }
}
```

---

## 13. Implementation Phases

| Phase | Scope | Estimate |
|-------|-------|----------|
| **Phase 1** | Stripe integration (cards) + Cloud Functions | 1 week |
| **Phase 2** | Apple Pay integration | 3-4 days |
| **Phase 3** | Google Pay integration | 3-4 days |
| **Phase 4** | PayPal integration | 1 week |
| **Phase 5** | Expert payouts (Stripe Connect) | 1 week |
| **Phase 6** | Refunds, disputes, admin dashboard | 1 week |

**Total Estimated Time: ~5-6 weeks**

---

## 14. Testing Strategy

### Unit Tests
- Payment service logic
- Money calculations
- Provider availability checks

### Integration Tests
- Stripe test mode payments
- PayPal sandbox transactions
- Webhook handling

### E2E Tests
- Complete booking + payment flow
- Refund flow
- Expert payout verification

### Test Cards/Accounts
```
Stripe Test Cards:
- Success: 4242 4242 4242 4242
- Decline: 4000 0000 0000 0002
- 3D Secure: 4000 0025 0000 3155

PayPal Sandbox:
- Use sandbox.paypal.com accounts
```

---

This architecture provides a **unified, provider-agnostic payment system** that's secure, scalable, and easy to extend with additional payment methods in the future.
