import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_client/features/crm/data/crm_api_service.dart';
import 'package:pos_client/features/crm/domain/models/gift_card.dart';
import 'package:pos_client/features/crm/domain/models/loyalty_settings.dart';
import 'package:pos_client/features/crm/domain/models/membership_tier.dart';
import 'package:pos_client/features/crm/domain/models/promotional_campaign.dart';
import 'package:pos_client/features/crm/domain/models/rfm_analytics.dart';
import 'package:pos_client/features/crm/presentation/controllers/crm_controller.dart';
import 'package:pos_client/features/crm/presentation/views/dialogs/issue_gift_card_dialog.dart';
import 'package:pos_client/features/crm/presentation/views/dialogs/membership_tier_dialog.dart';
import 'package:pos_client/features/customers/data/customers_api_service.dart';
import 'package:pos_client/features/customers/domain/models/customer.dart';
import 'package:pos_client/features/customers/domain/models/paginated_customers.dart';
import 'package:pos_client/features/customers/presentation/controllers/customer_controller.dart';
import 'package:pos_client/features/customers/presentation/views/customers_screen.dart';

class MockCustomersApiService implements CustomersApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PaginatedCustomersModel> getCustomers({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? isActive,
  }) async {
    return PaginatedCustomersModel(
      items: [
        CustomerModel(
          id: 'c1',
          businessId: 'biz1',
          name: 'Rahim VIP',
          phone: '01711111111',
          creditLimit: 5000,
          dueBalance: 1000,
          availableCredit: 4000,
          totalSalesCount: 12,
          totalSpent: 45000,
          isActive: true,
          loyaltyPointsBalance: 450,
          storeCreditBalance: 200,
          rfmSegment: 'CHAMPIONS',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 20,
      totalPages: 1,
      totalOutstandingDues: 1000,
    );
  }
}

class MockCrmApiService implements CrmApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<LoyaltySettingsModel> getSettings() async {
    return LoyaltySettingsModel(
      id: 'set1',
      businessId: 'biz1',
      isEnabled: true,
      earnRate: 1.0,
      redeemRate: 0.10,
      minRedeemPoints: 100,
      pointsExpiryDays: 365,
      maxCartDiscountPct: 50.0,
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<List<MembershipTierModel>> getTiers({bool? activeOnly}) async {
    return [
      MembershipTierModel(
        id: 'tier1',
        businessId: 'biz1',
        name: 'Gold Member',
        code: 'GOLD',
        minSpend: 50000,
        pointsMultiplier: 1.5,
        discountPct: 5.0,
        badgeColor: '#FFD700',
        perksDescription: 'VIP checkout & 5% off',
        sortOrder: 1,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<GiftCardModel>> getGiftCards({String? status, String? search}) async {
    return [
      GiftCardModel(
        id: 'gc1',
        businessId: 'biz1',
        cardNumber: 'GC-1111-2222-3333',
        initialBalance: 1000,
        currentBalance: 750,
        status: 'ACTIVE',
        recipientName: 'Sadia Sultana',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<RetentionKpisModel> getRfmAnalytics() async {
    return const RetentionKpisModel(
      totalActiveCustomers: 45,
      repeatPurchaseRate: 68.5,
      churnRate90d: 12.2,
      avgClv: 12500,
      revenueAtRisk: 85000,
      segments: [
        RfmSegmentSummary(
          segment: 'CHAMPIONS',
          count: 15,
          percentage: 33.3,
          totalMonetary: 350000,
          avgRecencyDays: 6.5,
        ),
      ],
    );
  }

  @override
  Future<List<PromotionalCampaignModel>> getCampaigns() async {
    return [
      PromotionalCampaignModel(
        id: 'camp1',
        businessId: 'biz1',
        title: 'VIP Weekend Flash 15%',
        targetSegment: 'CHAMPIONS',
        channel: 'SMS',
        messageTemplate: 'Dear VIP, get 15% off this weekend!',
        audienceCount: 15,
        status: 'DRAFT',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }
}

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        customersApiServiceProvider.overrideWithValue(MockCustomersApiService()),
        crmApiServiceProvider.overrideWithValue(MockCrmApiService()),
      ],
      child: const MaterialApp(
        home: CustomersScreen(),
      ),
    );
  }

  testWidgets('CustomersScreen renders with 5 tabs and initial directory tab', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Directory & Credit'), findsOneWidget);
    expect(find.text('Loyalty & Tiers'), findsOneWidget);
    expect(find.text('Gift Cards'), findsOneWidget);
    expect(find.text('RFM Segments & Retention'), findsOneWidget);
    expect(find.text('Promotional Campaigns'), findsOneWidget);

    expect(find.text('Rahim VIP'), findsOneWidget);
    expect(find.text('450 pts'), findsOneWidget);
  });

  testWidgets('Switching to Loyalty & Tiers tab renders loyalty settings and tiers', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Loyalty & Tiers'));
    await tester.tap(find.text('Loyalty & Tiers'));
    await tester.pumpAndSettle();

    expect(find.text('Membership VIP Tiers'), findsOneWidget);
    expect(find.text('Gold Member'), findsOneWidget);
    expect(find.text('Add Tier'), findsOneWidget);
    expect(find.text('Configure Settings'), findsOneWidget);
  });

  testWidgets('Switching to Gift Cards tab renders gift cards view', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gift Cards'));
    await tester.tap(find.text('Gift Cards'));
    await tester.pumpAndSettle();

    expect(find.text('Stored-Value Gift Cards'), findsOneWidget);
    expect(find.text('GC-1111-2222-3333'), findsOneWidget);
    expect(find.text('Issue Gift Card'), findsOneWidget);
  });

  testWidgets('Switching to RFM Segments tab renders retention metrics', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('RFM Segments & Retention'));
    await tester.tap(find.text('RFM Segments & Retention'));
    await tester.pumpAndSettle();

    expect(find.text('Customer Retention & Churn Analytics'), findsOneWidget);
    expect(find.text('68.5%'), findsOneWidget);
    expect(find.text('CHAMPIONS'), findsOneWidget);
  });

  testWidgets('Switching to Promotional Campaigns tab renders campaign table', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Promotional Campaigns'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Promotional Campaigns'));
    await tester.pumpAndSettle();

    expect(find.text('Targeted Promotional Campaigns'), findsOneWidget);
    expect(find.text('VIP Weekend Flash 15%'), findsOneWidget);
    expect(find.text('New Campaign'), findsOneWidget);
  });

  testWidgets('IssueGiftCardDialog renders balance, PIN, and button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: IssueGiftCardDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Issue New Gift Card'), findsOneWidget);
    expect(find.text('Issue Card'), findsOneWidget);
    expect(find.text('Auto-generate Card Number (GC-XXXX-XXXX-XXXX)'), findsOneWidget);
  });

  testWidgets('MembershipTierDialog renders tier fields and buttons', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MembershipTierDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Membership Tier'), findsOneWidget);
    expect(find.text('Create Tier'), findsOneWidget);
    expect(find.text('Badge Hex Color'), findsOneWidget);
  });
}
