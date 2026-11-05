import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/crm_api_service.dart';
import '../../domain/models/credit_note.dart';
import '../../domain/models/customer_loyalty_summary.dart';
import '../../domain/models/gift_card.dart';
import '../../domain/models/loyalty_settings.dart';
import '../../domain/models/membership_tier.dart';
import '../../domain/models/promotional_campaign.dart';
import '../../domain/models/rfm_analytics.dart';

final crmApiServiceProvider = Provider<CrmApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CrmApiService(apiClient: apiClient);
});

// ---------------------------------------------------------------------------
// Read Providers
// ---------------------------------------------------------------------------
final loyaltySettingsProvider = FutureProvider.autoDispose<LoyaltySettingsModel>((ref) async {
  final api = ref.watch(crmApiServiceProvider);
  return api.getSettings();
});

final membershipTiersProvider = FutureProvider.autoDispose<List<MembershipTierModel>>((ref) async {
  final api = ref.watch(crmApiServiceProvider);
  return api.getTiers();
});

final giftCardSearchQueryProvider = StateProvider<String>((ref) => '');

final giftCardsProvider = FutureProvider.autoDispose<List<GiftCardModel>>((ref) async {
  final api = ref.watch(crmApiServiceProvider);
  final search = ref.watch(giftCardSearchQueryProvider);
  return api.getGiftCards(search: search.isNotEmpty ? search : null);
});

final creditNotesProvider = FutureProvider.autoDispose<List<CreditNoteModel>>((ref) async {
  final api = ref.watch(crmApiServiceProvider);
  return api.getCreditNotes();
});

final rfmAnalyticsProvider = FutureProvider.autoDispose<RetentionKpisModel>((ref) async {
  final api = ref.watch(crmApiServiceProvider);
  return api.getRfmAnalytics();
});

final promotionalCampaignsProvider = FutureProvider.autoDispose<List<PromotionalCampaignModel>>((ref) async {
  final api = ref.watch(crmApiServiceProvider);
  return api.getCampaigns();
});

final selectedCustomerIdForLoyaltyProvider = StateProvider<String?>((ref) => null);

final customerLoyaltySummaryProvider = FutureProvider.autoDispose<CustomerLoyaltySummaryModel?>((ref) async {
  final customerId = ref.watch(selectedCustomerIdForLoyaltyProvider);
  if (customerId == null) return null;
  final api = ref.watch(crmApiServiceProvider);
  return api.getCustomerLoyalty(customerId);
});

// ---------------------------------------------------------------------------
// Controller & Action State
// ---------------------------------------------------------------------------
class CrmActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const CrmActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  CrmActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return CrmActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class CrmController extends StateNotifier<CrmActionState> {
  final Ref _ref;

  CrmController(this._ref) : super(const CrmActionState());

  CrmApiService get _api => _ref.read(crmApiServiceProvider);

  // -------------------------------------------------------------------------
  // Loyalty Settings
  // -------------------------------------------------------------------------
  Future<bool> updateSettings(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.updateSettings(data);
      _ref.invalidate(loyaltySettingsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Loyalty program settings updated successfully');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Membership Tiers
  // -------------------------------------------------------------------------
  Future<bool> createTier(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.createTier(data);
      _ref.invalidate(membershipTiersProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Membership tier created');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateTier(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.updateTier(id, data);
      _ref.invalidate(membershipTiersProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Membership tier updated');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteTier(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.deleteTier(id);
      _ref.invalidate(membershipTiersProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Membership tier deleted');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Customer Points Adjustments
  // -------------------------------------------------------------------------
  Future<bool> adjustCustomerPoints(String customerId, int points, String reason) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.adjustCustomerPoints(customerId, points, reason);
      _ref.invalidate(customerLoyaltySummaryProvider);
      state = state.copyWith(
        isLoading: false,
        successMessage: points > 0 ? 'Awarded $points bonus points' : 'Deducted ${points.abs()} points',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Gift Cards
  // -------------------------------------------------------------------------
  Future<GiftCardModel?> issueGiftCard(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final card = await _api.issueGiftCard(data);
      _ref.invalidate(giftCardsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Gift card ${card.cardNumber} issued');
      return card;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> reloadGiftCard(String cardId, double amount, {String? reference, String? notes}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.reloadGiftCard(cardId, amount, reference: reference, notes: notes);
      _ref.invalidate(giftCardsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Gift card balance reloaded');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> toggleGiftCardStatus(String cardId, String newStatus) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.toggleGiftCardStatus(cardId, newStatus);
      _ref.invalidate(giftCardsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Gift card status updated to $newStatus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Credit Notes
  // -------------------------------------------------------------------------
  Future<bool> createCreditNote(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.createCreditNote(data);
      _ref.invalidate(creditNotesProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Credit note issued');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Promotional Campaigns
  // -------------------------------------------------------------------------
  Future<bool> createCampaign(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.createCampaign(data);
      _ref.invalidate(promotionalCampaignsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Campaign created successfully');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateCampaign(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _api.updateCampaign(id, data);
      _ref.invalidate(promotionalCampaignsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Campaign updated');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<String?> exportCampaignCsv(String campaignId) async {
    try {
      return await _api.exportCampaignRecipients(campaignId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Export failed: $e');
      return null;
    }
  }

  void refreshAll() {
    _ref.invalidate(loyaltySettingsProvider);
    _ref.invalidate(membershipTiersProvider);
    _ref.invalidate(giftCardsProvider);
    _ref.invalidate(creditNotesProvider);
    _ref.invalidate(rfmAnalyticsProvider);
    _ref.invalidate(promotionalCampaignsProvider);
  }
}

final crmControllerProvider = StateNotifierProvider<CrmController, CrmActionState>((ref) {
  return CrmController(ref);
});

