import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../models/country_model.dart';

class CountryService extends GetxService {

  final RxList<CountryModel> _countries = <CountryModel>[].obs;
  final RxBool _isLoading = false.obs;

  List<CountryModel> get countries => _countries;
  bool get isLoading => _isLoading.value;

  Future<CountryService> init() async {
    // Load fallback countries immediately for offline use
    _loadFallbackCountries();
    // Fetch countries from API in background
    fetchCountries();
    return this;
  }
  
  Future<void> fetchCountries() async {
    try {
      _isLoading.value = true;
      
      final response = await http.get(Uri.parse(AppConstants.countriesApiUrl));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        final countries = data.map((json) => CountryModel.fromJson(json)).toList();
        
        // Sort countries alphabetically by name
        countries.sort((a, b) => a.name.compareTo(b.name));
        
        _countries.value = countries;
      } else {
        throw Exception('Failed to load countries');
      }
    } catch (e) {
      print('Error fetching countries: $e');
      // Load fallback countries if API fails
      _loadFallbackCountries();
    } finally {
      _isLoading.value = false;
    }
  }
  
  void _loadFallbackCountries() {
    _countries.value = [
      CountryModel(
        name: 'United States',
        code: 'US',
        flag: '🇺🇸',
        dialCode: '+1',
      ),
      CountryModel(
        name: 'United Kingdom',
        code: 'GB',
        flag: '🇬🇧',
        dialCode: '+44',
      ),
      CountryModel(
        name: 'Canada',
        code: 'CA',
        flag: '🇨🇦',
        dialCode: '+1',
      ),
      CountryModel(
        name: 'Australia',
        code: 'AU',
        flag: '🇦🇺',
        dialCode: '+61',
      ),
      CountryModel(
        name: 'Germany',
        code: 'DE',
        flag: '🇩🇪',
        dialCode: '+49',
      ),
      CountryModel(
        name: 'France',
        code: 'FR',
        flag: '🇫🇷',
        dialCode: '+33',
      ),
      CountryModel(
        name: 'Japan',
        code: 'JP',
        flag: '🇯🇵',
        dialCode: '+81',
      ),
      CountryModel(
        name: 'India',
        code: 'IN',
        flag: '🇮🇳',
        dialCode: '+91',
      ),
      CountryModel(
        name: 'Saudi Arabia',
        code: 'SA',
        flag: '🇸🇦',
        dialCode: '+966',
      ),
      CountryModel(
        name: 'United Arab Emirates',
        code: 'AE',
        flag: '🇦🇪',
        dialCode: '+971',
      ),
    ];
  }
  
  CountryModel? getCountryByCode(String code) {
    try {
      return _countries.firstWhere((country) => country.code == code);
    } catch (e) {
      return null;
    }
  }
  
  List<CountryModel> searchCountries(String query) {
    if (query.isEmpty) return _countries;
    
    return _countries.where((country) {
      return country.name.toLowerCase().contains(query.toLowerCase()) ||
             country.code.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
}
