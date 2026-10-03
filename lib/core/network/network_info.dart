import 'package:connectivity_plus/connectivity_plus.dart';

/// واجهة مجردة لفحص الاتصال بالشبكة، تعتمد عليها كل الـ Repositories
/// عبر المشروع بدل التحقق المباشر من الشبكة.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    final result = await connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
