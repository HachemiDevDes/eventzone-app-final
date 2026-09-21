import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class DeviceContactsService {
  /// Saves the contact directly to Android / iOS contacts address book.
  static Future<bool> saveContactToDevice({
    required String name,
    String? title,
    String? company,
    String? department,
    String? email,
    String? phone,
    String? website,
    String? address,
    String? notes,
  }) async {
    try {
      final trimmedName = name.trim();
      final parts = trimmedName.split(RegExp(r'\s+'));
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final comp = company?.trim() ?? '';
      final titl = title?.trim() ?? '';
      final dept = department?.trim() ?? '';

      final contact = Contact(
        name: Name(first: firstName, last: lastName),
        phones: (phone != null && phone.trim().isNotEmpty)
            ? [Phone(number: phone.trim())]
            : const [],
        emails: (email != null && email.trim().isNotEmpty)
            ? [Email(address: email.trim())]
            : const [],
        organizations: (comp.isNotEmpty || titl.isNotEmpty || dept.isNotEmpty)
            ? [Organization(name: comp, jobTitle: titl, departmentName: dept)]
            : const [],
        websites: (website != null && website.trim().isNotEmpty)
            ? [Website(url: website.trim())]
            : const [],
        addresses: (address != null && address.trim().isNotEmpty)
            ? [Address(formatted: address.trim(), street: address.trim())]
            : const [],
        notes: (notes != null && notes.trim().isNotEmpty)
            ? [Note(note: notes.trim())]
            : const [],
      );

      // Check / request permission
      final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
      if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
        await FlutterContacts.create(contact);
        return true;
      }

      // If direct permission is denied, try showing native contact creator
      try {
        final creatorResult = await FlutterContacts.native.showCreator(contact: contact);
        return creatorResult != null;
      } catch (_) {
        return false;
      }
    } catch (e) {
      debugPrint('Failed to save contact to device address book: $e');
      return false;
    }
  }
}
