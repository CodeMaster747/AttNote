import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight online check for gating auth actions.
class ConnectivityHelper {
  ConnectivityHelper._();

  static Future<bool> get hasConnection async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
