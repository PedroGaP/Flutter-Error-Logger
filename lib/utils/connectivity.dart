import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivitFEL {
  static Future<bool> isConnected() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    return connectivityResult.contains(ConnectivityResult.ethernet) ||
        connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.vpn);
  }
}
