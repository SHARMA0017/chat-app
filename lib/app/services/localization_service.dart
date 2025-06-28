import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends GetxService {
  static const String _languageKey = 'selected_language';
  
  final Rx<Locale> _locale = const Locale('en', 'US').obs;
  Locale get locale => _locale.value;
  
  late SharedPreferences _prefs;
  
  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('ar', 'SA'),
  ];
  
  // Language names for UI
  static const Map<String, String> languageNames = {
    'en': 'English',
    'ar': 'العربية',
  };
  
  Future<LocalizationService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedLanguage();
    return this;
  }
  
  Future<void> _loadSavedLanguage() async {
    final savedLanguage = _prefs.getString(_languageKey);
    if (savedLanguage != null) {
      final locale = _getLocaleFromLanguageCode(savedLanguage);
      if (locale != null) {
        _locale.value = locale;
        Get.updateLocale(locale);
      }
    }
  }
  
  Future<void> changeLanguage(String languageCode) async {
    final locale = _getLocaleFromLanguageCode(languageCode);
    if (locale != null) {
      _locale.value = locale;
      await _prefs.setString(_languageKey, languageCode);
      Get.updateLocale(locale);
    }
  }
  
  Locale? _getLocaleFromLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return const Locale('en', 'US');
      case 'ar':
        return const Locale('ar', 'SA');
      default:
        return null;
    }
  }
  
  String getCurrentLanguageCode() {
    return _locale.value.languageCode;
  }
  
  String getCurrentLanguageName() {
    return languageNames[getCurrentLanguageCode()] ?? 'English';
  }
  
  bool isRTL() {
    return _locale.value.languageCode == 'ar';
  }
}

// Translation keys and values
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      // Common
      'app_name': 'Chat App',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'retry': 'Retry',
      
      // Authentication
      'login': 'Login',
      'register': 'Register',
      'logout': 'Logout',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'display_name': 'Display Name',
      'mobile': 'Mobile Number',
      'country': 'Country',
      'login_button': 'Login',
      'signup_button': 'Sign Up',
      'already_have_account': 'Already have an account?',
      'dont_have_account': "Don't have an account?",
      
      // Validation
      'email_required': 'Email is required',
      'email_invalid': 'Please enter a valid email',
      'password_required': 'Password is required',
      'password_min_length': 'Password must be at least 6 characters',
      'passwords_dont_match': 'Passwords do not match',
      'display_name_required': 'Display name is required',
      'mobile_required': 'Mobile number is required',
      'mobile_invalid': 'Please enter a valid mobile number',
      'country_required': 'Please select a country',
      
      // Home
      'home': 'Home',
      'chats': 'Chats',
      'no_chats': 'No chats yet',
      'start_chatting': 'Start a new conversation',
      
      // Chat
      'chat': 'Chat',
      'type_message': 'Type a message...',
      'send': 'Send',
      'online': 'Online',
      'offline': 'Offline',
      'typing': 'Typing...',
      
      // Map
      'map': 'Map',
      'current_location': 'Current Location',
      'location_permission_denied': 'Location permission denied',
      'location_service_disabled': 'Location service disabled',
      
      // QR Code
      'qr_scanner': 'QR Scanner',
      'qr_generator': 'QR Generator',
      'scan_qr': 'Scan QR Code',
      'generate_qr': 'Generate QR Code',
      'share_device_token': 'Share Device Token',
      'scan_to_connect': 'Scan to connect with another user',
      
      // Settings
      'settings': 'Settings',
      'language': 'Language',
      'change_language': 'Change Language',
      'profile': 'Profile',
      'about': 'About',
      
      // Messages
      'login_success': 'Login successful',
      'login_failed': 'Login failed',
      'registration_success': 'Registration successful',
      'registration_failed': 'Registration failed',
      'user_already_exists': 'User already exists',
      'message_sent': 'Message sent',
      'message_failed': 'Failed to send message',
    },
    'ar_SA': {
      // Common
      'app_name': 'تطبيق الدردشة',
      'ok': 'موافق',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'retry': 'إعادة المحاولة',
      
      // Authentication
      'login': 'تسجيل الدخول',
      'register': 'التسجيل',
      'logout': 'تسجيل الخروج',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'confirm_password': 'تأكيد كلمة المرور',
      'display_name': 'اسم العرض',
      'mobile': 'رقم الهاتف',
      'country': 'البلد',
      'login_button': 'تسجيل الدخول',
      'signup_button': 'إنشاء حساب',
      'already_have_account': 'لديك حساب بالفعل؟',
      'dont_have_account': 'ليس لديك حساب؟',
      
      // Validation
      'email_required': 'البريد الإلكتروني مطلوب',
      'email_invalid': 'يرجى إدخال بريد إلكتروني صحيح',
      'password_required': 'كلمة المرور مطلوبة',
      'password_min_length': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
      'passwords_dont_match': 'كلمات المرور غير متطابقة',
      'display_name_required': 'اسم العرض مطلوب',
      'mobile_required': 'رقم الهاتف مطلوب',
      'mobile_invalid': 'يرجى إدخال رقم هاتف صحيح',
      'country_required': 'يرجى اختيار البلد',
      
      // Home
      'home': 'الرئيسية',
      'chats': 'المحادثات',
      'no_chats': 'لا توجد محادثات بعد',
      'start_chatting': 'ابدأ محادثة جديدة',
      
      // Chat
      'chat': 'المحادثة',
      'type_message': 'اكتب رسالة...',
      'send': 'إرسال',
      'online': 'متصل',
      'offline': 'غير متصل',
      'typing': 'يكتب...',
      
      // Map
      'map': 'الخريطة',
      'current_location': 'الموقع الحالي',
      'location_permission_denied': 'تم رفض إذن الموقع',
      'location_service_disabled': 'خدمة الموقع معطلة',
      
      // QR Code
      'qr_scanner': 'ماسح QR',
      'qr_generator': 'مولد QR',
      'scan_qr': 'مسح رمز QR',
      'generate_qr': 'إنشاء رمز QR',
      'share_device_token': 'مشاركة رمز الجهاز',
      'scan_to_connect': 'امسح للاتصال مع مستخدم آخر',
      
      // Settings
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'change_language': 'تغيير اللغة',
      'profile': 'الملف الشخصي',
      'about': 'حول',
      
      // Messages
      'login_success': 'تم تسجيل الدخول بنجاح',
      'login_failed': 'فشل تسجيل الدخول',
      'registration_success': 'تم التسجيل بنجاح',
      'registration_failed': 'فشل التسجيل',
      'user_already_exists': 'المستخدم موجود بالفعل',
      'message_sent': 'تم إرسال الرسالة',
      'message_failed': 'فشل في إرسال الرسالة',
    },
  };
}
