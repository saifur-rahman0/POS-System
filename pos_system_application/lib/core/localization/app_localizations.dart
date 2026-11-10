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
      'lang_en': 'EN',
      'lang_bn': 'বাংলা',
      'refreshed_toast': 'refreshed',

      // Product View Modes
      'view_grid': 'Grid',
      'view_table': 'Table',
      'barcode_sku': 'SKU / Barcode',
      'product_name': 'Product Name',
      'category': 'Category',
      'price': 'Price',
      'stock_level': 'Stock',
      'action': 'Action',
      'add_to_cart': 'Add',
      'no_products': 'No matching products found',
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

      // Transactions Hub
      'transactions_hub': 'Transactions Hub',
      'all_transactions': 'All Transactions',
      'total_inflow': 'Total Inflow',
      'total_outflow': 'Total Outflow',
      'net_cash_flow': 'Net Cash Flow',
      'ledger_entries': 'Total Ledger Entries',
      'sales_receipts': 'Sales Receipts',
      'purchases_orders': 'Purchases',
      'payments_tenders': 'Payments & Tenders',

      // Settings
      'store_profile': 'Store Profile',
      'hardware_printers': 'Hardware & Printers',
      'offline_licensing': 'Offline Licensing',
      'database_backups': 'Database Backups',
      'system_preferences': 'System Preferences',

      // Auth
      'login_title': 'Retail POS Terminal',
      'login_subtitle': 'Sign in to access cash register & store management',
      'username_or_email': 'Username or Email',
      'password': 'Password',
      'sign_in': 'Sign In to Terminal',
      'signing_in': 'Signing In...',
      'quick_login': 'Quick Cashier Login (dev_cashier)',
      'new_store_question': "Don't have an account?",
      'register_link': 'Register New Store',
      'register_title': 'Register New Store',
      'register_subtitle': 'Set up your retail business and admin terminal',
      'business_name': 'Business / Store Name',
      'full_name': 'Full Name (Display Name)',
      'email_optional': 'Email (Optional)',
      'phone_optional': 'Phone Number (Optional)',
      'confirm_password': 'Confirm Password',
      'create_account': 'Create Account & Terminal',
      'already_have_account': 'Already have an account?',
      'login_link': 'Sign In',
      'logout': 'Logout',
      'switch_user': 'Switch User',
      'confirm_logout': 'Are you sure you want to sign out of this terminal?',

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
      'lang_en': 'EN',
      'lang_bn': 'বাংলা',
      'refreshed_toast': 'রিফ্রেশ সম্পন্ন',

      // Product View Modes
      'view_grid': 'গ্রিড',
      'view_table': 'টেবিল',
      'barcode_sku': 'SKU / বারকোড',
      'product_name': 'পণ্যের নাম',
      'category': 'ক্যাটাগরি',
      'price': 'মূল্য',
      'stock_level': 'স্টক',
      'action': 'অ্যাকশন',
      'add_to_cart': 'যুক্ত',
      'no_products': 'কোনো পণ্য পাওয়া যায়নি',

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

      // Transactions Hub
      'transactions_hub': 'লেনদেন ইতিহাস',
      'all_transactions': 'সকল লেনদেন',
      'total_inflow': 'মোট আগমন (আয়)',
      'total_outflow': 'মোট নির্গমন (ব্যয়)',
      'net_cash_flow': 'নীট নগদ প্রবাহ',
      'ledger_entries': 'মোট লেনদেন সংখ্যা',
      'sales_receipts': 'বিক্রয় রসিদ',
      'purchases_orders': 'ক্রয় ও সাপ্লায়ার',
      'payments_tenders': 'পেমেন্ট ও মাধ্যম',

      // Settings
      'store_profile': 'দোকানের তথ্য',
      'hardware_printers': 'হার্ডওয়্যার ও প্রিন্টার',
      'offline_licensing': 'অফলাইন লাইসেন্স',
      'database_backups': 'ডাটাবেজ ব্যাকআপ',
      'system_preferences': 'সিস্টেম পছন্দসমূহ',

      // Auth
      'login_title': 'রিটেল পিওএস টার্মিনাল',
      'login_subtitle': 'ক্যাশ রেজিস্টার ও দোকান ব্যবস্থাপনায় প্রবেশ করুন',
      'username_or_email': 'ইউজারনেম অথবা ইমেইল',
      'password': 'পাসওয়ার্ড',
      'sign_in': 'লগইন করুন',
      'signing_in': 'লগইন হচ্ছে...',
      'quick_login': 'দ্রুত ক্যাশিয়ার লগইন (dev_cashier)',
      'new_store_question': 'নতুন একাউন্ট বা দোকান খুলতে চান?',
      'register_link': 'নতুন দোকান নিবন্ধন করুন',
      'register_title': 'নতুন দোকান নিবন্ধন',
      'register_subtitle': 'আপনার রিটেল ব্যবসা ও এডমিন টার্মিনাল তৈরি করুন',
      'business_name': 'দোকানের নাম',
      'full_name': 'সম্পূর্ণ নাম',
      'email_optional': 'ইমেইল (ঐচ্ছিক)',
      'phone_optional': 'ফোন নম্বর (ঐচ্ছিক)',
      'confirm_password': 'পাসওয়ার্ড নিশ্চিত করুন',
      'create_account': 'অ্যাকাউন্ট তৈরি করুন',
      'already_have_account': 'ইতিমধ্যে অ্যাকাউন্ট আছে?',
      'login_link': 'লগইন',
      'logout': 'লগআউট',
      'switch_user': 'ব্যবহারকারী পরিবর্তন',
      'confirm_logout': 'আপনি কি এই টার্মিনাল থেকে লগআউট করতে চান?',

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

