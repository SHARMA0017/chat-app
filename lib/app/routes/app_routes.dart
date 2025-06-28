// ignore_for_file: constant_identifier_names

abstract class Routes {
  Routes._();

  static const SPLASH = _Paths.SPLASH;
  static const LOGIN = _Paths.LOGIN;
  static const REGISTER = _Paths.REGISTER;
  static const HOME = _Paths.HOME;
  static const CHAT = _Paths.CHAT;
  static const MAP = _Paths.MAP;
  static const PROFILE = _Paths.PROFILE;
  static const QR_SCANNER = _Paths.QR_SCANNER;
  static const QR_GENERATOR = _Paths.QR_GENERATOR;
}

abstract class _Paths {
  _Paths._();

  static const SPLASH = '/splash';
  static const LOGIN = '/login';
  static const REGISTER = '/register';
  static const HOME = '/home';
  static const CHAT = '/chat';
  static const MAP = '/map';
  static const PROFILE = '/profile';
  static const QR_SCANNER = '/qr-scanner';
  static const QR_GENERATOR = '/qr-generator';
}
