import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLanguageProvider = StateProvider<String>((ref) => 'en');

class AppLocalizations {
  final String languageCode;

  const AppLocalizations(this.languageCode);

  bool get isBangla => languageCode == 'bn';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Shell / Nav
      'app_title': 'Retail POS — Local Terminal',
      'terminal_counter': 'COUNTER 01',
      'pos_register': 'POS Register',
      'catalog_stock': 'Catalog & Stock',
      'purchasing': 'Purchasing',
      'sales_history': 'Sales History',
      'expenses': 'Expenses',
      'accounts': 'Accounts',
      'customers': 'Customers',
      'stores_transfers': 'Stores & Transfers',
      'reports': 'Reports',
      'settings': 'Settings',

      // Header Status
      'shift_active': 'Shift Active',
      'shift_inactive': 'Shift Inactive',
      'sync_ready': 'Sync: Ready',
      'syncing': 'Syncing...',
      'refresh': 'Refresh',
      'refreshing': 'Refreshing...',
      'shortcuts': 'Shortcuts (F1)',
      'lang_toggle': 'বাংলা',

      // POS Register
      'search_hint': 'Scan barcode or search product name / SKU...',
      'all_products': 'All Products',
      'order': 'Order',
      'items': 'items',
      'walk_in_customer': 'Walk-in Customer',
      'cart_empty': 'Cart is empty',
      'cart_ready': 'Register ready · Scan barcode or click product tiles to begin sale',
      'subtotal': 'Subtotal',
      'discount': 'Discount',
      'vat_tax': 'VAT / Tax',
      'delivery_fee': 'Delivery Fee',
      'grand_total': 'Grand Total',
      'pay': 'Pay',
      'quick_cash': 'Quick Cash Tender',
      'exact': 'Exact',
      'park_order': 'Park Order',
      'clear': 'Clear',
      'stock': 'Stock:',
      'out_of_stock': 'Out of stock',

      // Catalog & Inventory
      'products': 'Products',
      'categories': 'Categories',
      'advanced_inventory': 'Advanced Inventory',
      'pricing_promotions': 'Pricing & Promotions',
      'adv_inventory_mgmt': 'Advanced Inventory Management',
      'batches_expiry': 'Batches & Expiry',
      'physical_audits': 'Physical Audits',
      'damaged_stock': 'Damaged Stock',
      'reservations': 'Reservations',
      'reorder_valuation': 'Reorder & Valuation',

      // Branches & Transfers
      'branches_title': 'Store Branches & Transfers',
      'retail_branches': 'Retail Branches',
      'stock_transfers': 'Stock Transfers',

      // Settings
      'store_profile': 'Store Profile',
      'hardware_printers': 'Hardware & Printers',
      'offline_licensing': 'Offline Licensing',
      'database_backups': 'Database Backups',
      'system_preferences': 'System Preferences',

      // General
      'retry': 'Retry',
      'cancel': 'Cancel',
      'apply': 'Apply',
      'save': 'Save',
    },
    'bn': {
      // Shell / Nav
      'app_title': 'রিটেল পিওএস — লোকাল টার্মিনাল',
      'terminal_counter': 'কাউন্টার ০১',
      'pos_register': 'ক্যাশ রেজিস্টার',
      'catalog_stock': 'ক্যাটালগ ও স্টক',
      'purchasing': 'ক্রয় ও সাপ্লায়ার',
      'sales_history': 'বিক্রয়ের ইতিহাস',
      'expenses': 'ব্যয় ব্যবস্থাপনা',
      'accounts': 'আর্থিক হিসাব',
      'customers': 'গ্রাহক তালিকা',
      'stores_transfers': 'শাখা ও স্থানান্তর',
      'reports': 'প্রতিবেদন ও তথ্য',
      'settings': 'সিস্টেম সেটিংস',

      // Header Status
      'shift_active': 'শিফট চালু',
      'shift_inactive': 'শিফট বন্ধ',
      'sync_ready': 'সিঙ্ক: প্রস্তুত',
      'syncing': 'সিঙ্ক হচ্ছে...',
      'refresh': 'রিফ্রেশ',
      'refreshing': 'রিফ্রেশ হচ্ছে...',
      'shortcuts': 'শর্টকাট (F1)',
      'lang_toggle': 'English',

      // POS Register
      'search_hint': 'বারকোড স্ক্যান করুন অথবা পণ্যের নাম / SKU খুঁজুন...',
      'all_products': 'সব পণ্য',
      'order': 'অর্ডার',
      'items': 'আইটেম',
      'walk_in_customer': 'সাধারণ ক্রেতা',
      'cart_empty': 'Cart is empty',
      'cart_ready': 'রেজিস্টার প্রস্তুত · বারকোড স্ক্যান করুন অথবা পণ্য নির্বাচন করুন',
      'subtotal': 'মোট মূল্য',
      'discount': 'ছাড়',
      'vat_tax': 'ভ্যাট / ট্যাক্স',
      'delivery_fee': 'ডেলিভারি চার্জ',
      'grand_total': 'সর্বমোট',
      'pay': 'পরিশোধ',
      'quick_cash': 'দ্রুত নগদ পরিশোধ',
      'exact': 'সঠিক',
      'park_order': 'অর্ডার হোল্ড',
      'clear': 'খালি করুন',
      'stock': 'স্টক:',
      'out_of_stock': 'স্টকে নেই',

      // Catalog & Inventory
      'products': 'পণ্যসমূহ',
      'categories': 'ক্যাটাগরি',
      'advanced_inventory': 'উন্নত ইনভেন্টরি',
      'pricing_promotions': 'মূল্য ও প্রমোশন',
      'adv_inventory_mgmt': 'উন্নত ইনভেন্টরি ব্যবস্থাপনা',
      'batches_expiry': 'ব্যাচ ও মেয়াদ',
      'physical_audits': 'স্টক অডিট',
      'damaged_stock': 'নষ্ট পণ্য',
      'reservations': 'সংরক্ষিত স্টক',
      'reorder_valuation': 'রিঅর্ডার ও স্টক মূল্যায়ন',

      // Branches & Transfers
      'branches_title': 'দোকানের শাখা ও স্টক স্থানান্তর',
      'retail_branches': 'শাখা তালিকা',
      'stock_transfers': 'স্টক স্থানান্তর',

      // Settings
      'store_profile': 'দোকানের তথ্য',
      'hardware_printers': 'হার্ডওয়্যার ও প্রিন্টার',
      'offline_licensing': 'অফলাইন লাইসেন্স',
      'database_backups': 'ডাটাবেজ ব্যাকআপ',
      'system_preferences': 'সিস্টেম পছন্দসমূহ',

      // General
      'retry': 'পুনরায় চেষ্টা',
      'cancel': 'বাতিল',
      'apply': 'প্রয়োগ করুন',
      'save': 'সংরক্ষণ',
    },
  };

  String tr(String key, [String? fallback]) {
    final values = _localizedValues[languageCode];
    if (values != null && values.containsKey(key)) {
      return values[key]!;
    }
    return fallback ?? key;
  }
}

final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final lang = ref.watch(appLanguageProvider);
  return AppLocalizations(lang);
});

