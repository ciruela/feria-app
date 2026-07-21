import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeRateService extends ChangeNotifier {
  static const _rateKey = 'exchange_rate_ars';
  static const _updatedAtKey = 'exchange_rate_updated_at';
  static const defaultRate = 1500.0;

  double _rate = defaultRate;
  DateTime? _updatedAt;

  double get rate => _rate;
  DateTime? get updatedAt => _updatedAt;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _rate = prefs.getDouble(_rateKey) ?? defaultRate;
    final timestamp = prefs.getInt(_updatedAtKey);
    _updatedAt = timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
    notifyListeners();
  }

  Future<void> saveRate(double newRate) async {
    if (newRate <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    _rate = newRate;
    _updatedAt = DateTime.now();

    await prefs.setDouble(_rateKey, _rate);
    await prefs.setInt(_updatedAtKey, _updatedAt!.millisecondsSinceEpoch);
    notifyListeners();
  }

  double toArs(double usd) => usd * _rate;
}
