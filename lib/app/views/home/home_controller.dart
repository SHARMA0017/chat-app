import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class HomeController extends GetxController {
  late AuthService _authService;
  late DatabaseService _databaseService;
  late LocalizationService _localizationService;

  final RxList<Map<String, dynamic>> chatRooms = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  
  UserModel? get currentUser => _authService.currentUser;
  
  @override
  void onInit() {
    super.onInit();
    _authService = Get.find<AuthService>();
    _databaseService = Get.find<DatabaseService>();
    _localizationService = Get.find<LocalizationService>();
    _loadChatRooms();
  }
  
  Future<void> _loadChatRooms() async {
    if (currentUser == null) return;

    try {
      isLoading.value = true;
      final rooms = await _databaseService.getChatRooms(currentUser!.id!);
      chatRooms.value = rooms;
    } catch (e) {
      print('Error loading chat rooms: $e');
    } finally {
      isLoading.value = false;
    }
  }


  
  void goToChat(String userId, String userName) {
    Get.toNamed(Routes.CHAT, arguments: {
      'userId': userId,
      'userName': userName,
    });
  }
  
  void goToMap() {
    Get.toNamed(Routes.MAP);
  }
  
  void goToQRScanner() {
    Get.toNamed(Routes.QR_SCANNER);
  }
  
  void goToProfile() {
    Get.toNamed(Routes.PROFILE);
  }
  
  void changeLanguage() {
    final currentLang = _localizationService.getCurrentLanguageCode();
    final newLang = currentLang == 'en' ? 'ar' : 'en';
    _localizationService.changeLanguage(newLang);
  }
  
  Future<void> logout() async {
    await _authService.logout();
    Get.offAllNamed(Routes.LOGIN);
  }
  
  void refreshChatRooms() {
    _loadChatRooms();
  }




}
