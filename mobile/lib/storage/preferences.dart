import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _recentServersKey = 'recent_servers';

  static Future<List<Map<String, dynamic>>> getRecentServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentServersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> addRecentServer(String host, int port) async {
    final servers = await getRecentServers();
    servers.removeWhere((s) => s['host'] == host && s['port'] == port);
    servers.insert(0, {'host': host, 'port': port});
    if (servers.length > 10) {
      servers.removeRange(10, servers.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentServersKey, jsonEncode(servers));
  }
}
