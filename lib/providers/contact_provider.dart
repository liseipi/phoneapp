import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact.dart' as model;

class ContactProvider with ChangeNotifier {
  List<model.Contact> _contacts = [];
  List<model.Contact> _filteredContacts = [];
  bool _isLoading = false;

  List<model.Contact> get contacts => _filteredContacts;
  bool get isLoading => _isLoading;

  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 检查权限
      final permission = await Permission.contacts.status;
      if (!permission.isGranted) {
        final result = await Permission.contacts.request();
        if (!result.isGranted) {
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // 获取联系人（包含电话号码）
      final List<Contact> deviceContacts =
      await FlutterContacts.getContacts(withProperties: true);

      _contacts = deviceContacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) {
        final phone = c.phones.first.number;
        return model.Contact(
          name: c.displayName.isNotEmpty ? c.displayName : '未知',
          phoneNumber: phone.replaceAll(RegExp(r'[^\d+]'), ''),
        );
      })
          .toList();

      _contacts.sort((a, b) => a.name.compareTo(b.name));
      _filteredContacts = List.from(_contacts);
    } catch (e) {
      debugPrint('加载联系人失败: $e');
      _contacts = [];
      _filteredContacts = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void searchContacts(String query) {
    if (query.isEmpty) {
      _filteredContacts = List.from(_contacts);
    } else {
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(query.toLowerCase()) ||
            contact.phoneNumber.contains(query);
      }).toList();
    }
    notifyListeners();
  }
}