import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/credit_note.dart';
import '../domain/models/customer_loyalty_summary.dart';
import '../domain/models/gift_card.dart';
import '../domain/models/loyalty_settings.dart';
import '../domain/models/loyalty_transaction.dart';
import '../domain/models/membership_tier.dart';
import '../domain/models/promotional_campaign.dart';
import '../domain/models/rfm_analytics.dart';

class CrmApiService {
  final ApiClient _apiClient;

  CrmApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // -------------------------------------------------------------------------
  // Loyalty Settings
  // -------------------------------------------------------------------------
  Future<LoyaltySettingsModel> getSettings() async {
    try {
      final res = await _apiClient.dio.get('/crm/settings');
      return LoyaltySettingsModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<LoyaltySettingsModel> updateSettings(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.put('/crm/settings', data: data);
      return LoyaltySettingsModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Membership Tiers
  // -------------------------------------------------------------------------
  Future<List<MembershipTierModel>> getTiers({bool? activeOnly}) async {
    try {
      final res = await _apiClient.dio.get(
        '/crm/tiers',
        queryParameters: {if (activeOnly != null) 'active_only': activeOnly},
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => MembershipTierModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<MembershipTierModel> createTier(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/crm/tiers', data: data);
      return MembershipTierModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<MembershipTierModel> updateTier(String id, Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.put('/crm/tiers/$id', data: data);
      return MembershipTierModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<void> deleteTier(String id) async {
    try {
      await _apiClient.dio.delete('/crm/tiers/$id');
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Customer Loyalty & Points
  // -------------------------------------------------------------------------
  Future<CustomerLoyaltySummaryModel> getCustomerLoyalty(String customerId) async {
    try {
      final res = await _apiClient.dio.get('/crm/customers/$customerId/loyalty');
      return CustomerLoyaltySummaryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<LoyaltyTransactionModel> adjustCustomerPoints(
    String customerId,
    int points,
    String reason,
  ) async {
    try {
      final res = await _apiClient.dio.post(
        '/crm/customers/$customerId/loyalty/adjust',
        data: {'points': points, 'reason': reason},
      );
      return LoyaltyTransactionModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Gift Cards
  // -------------------------------------------------------------------------
  Future<List<GiftCardModel>> getGiftCards({String? status, String? search}) async {
    try {
      final res = await _apiClient.dio.get(
        '/crm/gift-cards',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => GiftCardModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<GiftCardModel> issueGiftCard(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/crm/gift-cards', data: data);
      return GiftCardModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<GiftCardVerifyResult> verifyGiftCard(String cardNumber, String pin) async {
    try {
      final res = await _apiClient.dio.post(
        '/crm/gift-cards/verify',
        data: {'card_number': cardNumber, 'pin': pin},
      );
      return GiftCardVerifyResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<void> reloadGiftCard(
    String cardId,
    double amount, {
    String? reference,
    String? notes,
  }) async {
    try {
      await _apiClient.dio.post(
        '/crm/gift-cards/$cardId/reload',
        data: {
          'amount': amount,
          if (reference != null) 'reference': reference,
          if (notes != null) 'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<GiftCardModel> toggleGiftCardStatus(String cardId, String newStatus) async {
    try {
      final res = await _apiClient.dio.post(
        '/crm/gift-cards/$cardId/toggle-status',
        queryParameters: {'new_status': newStatus},
      );
      return GiftCardModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Credit Notes
  // -------------------------------------------------------------------------
  Future<List<CreditNoteModel>> getCreditNotes({
    String? customerId,
    String? status,
    String? search,
  }) async {
    try {
      final res = await _apiClient.dio.get(
        '/crm/credit-notes',
        queryParameters: {
          if (customerId != null) 'customer_id': customerId,
          if (status != null) 'status': status,
          if (search != null) 'search': search,
        },
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => CreditNoteModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<CreditNoteModel> createCreditNote(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/crm/credit-notes', data: data);
      return CreditNoteModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // RFM & Retention Analytics
  // -------------------------------------------------------------------------
  Future<RetentionKpisModel> getRfmAnalytics() async {
    try {
      final res = await _apiClient.dio.get('/crm/rfm-analytics');
      return RetentionKpisModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Promotional Campaigns
  // -------------------------------------------------------------------------
  Future<List<PromotionalCampaignModel>> getCampaigns() async {
    try {
      final res = await _apiClient.dio.get('/crm/campaigns');
      final list = res.data as List<dynamic>;
      return list.map((e) => PromotionalCampaignModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PromotionalCampaignModel> createCampaign(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/crm/campaigns', data: data);
      return PromotionalCampaignModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PromotionalCampaignModel> updateCampaign(String id, Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.put('/crm/campaigns/$id', data: data);
      return PromotionalCampaignModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<String> exportCampaignRecipients(String campaignId) async {
    try {
      final res = await _apiClient.dio.get(
        '/crm/campaigns/$campaignId/export-recipients',
        options: Options(responseType: ResponseType.plain),
      );
      return res.data as String;
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}

