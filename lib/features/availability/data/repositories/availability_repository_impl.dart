import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/availability.dart';
import '../../domain/repositories/availability_repository.dart';
import '../models/availability_models.dart';

/// Firestore implementation backed by `availability` and `blockedDates`.
class AvailabilityRepositoryImpl implements AvailabilityRepository {
  AvailabilityRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rules =>
      _db.collection('availability');
  CollectionReference<Map<String, dynamic>> get _blocked =>
      _db.collection('blockedDates');

  @override
  Stream<List<AvailabilityRule>> watchRules(String facultyId) {
    return _rules
        .where('facultyId', isEqualTo: facultyId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AvailabilityModel.fromMap(d.id, d.data())).toList()
              ..sort(_ruleSort));
  }

  /// Sort: one-off dates first (chronological), then weekday, then start time.
  int _ruleSort(AvailabilityRule a, AvailabilityRule b) {
    if (a.isOneOff != b.isOneOff) return a.isOneOff ? -1 : 1;
    if (a.isOneOff && b.isOneOff) {
      final c = a.specificDate!.compareTo(b.specificDate!);
      if (c != 0) return c;
    } else {
      final c = (a.dayOfWeek ?? 0).compareTo(b.dayOfWeek ?? 0);
      if (c != 0) return c;
    }
    return a.startTime.compareTo(b.startTime);
  }

  @override
  Stream<List<BlockedDate>> watchBlockedDates(String facultyId) {
    return _blocked
        .where('facultyId', isEqualTo: facultyId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BlockedDateModel.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => a.date.compareTo(b.date)));
  }

  @override
  Future<String> addRule(String facultyId, AvailabilityInput input) async {
    final ref = await _rules.add({
      ...input.toMap(facultyId),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> updateRule(String ruleId, Map<String, dynamic> patch) {
    return _rules.doc(ruleId).update({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> toggleRule(String ruleId, bool isActive) {
    return updateRule(ruleId, {'isActive': isActive});
  }

  @override
  Future<void> deleteRule(String ruleId) => _rules.doc(ruleId).delete();

  @override
  Future<String> blockDate(
      String facultyId, String dateKey, String reason) async {
    final ref = await _blocked.add(BlockedDateModel(
      id: '',
      facultyId: facultyId,
      date: dateKey,
      reason: reason,
    ).toMap());
    return ref.id;
  }

  @override
  Future<void> unblockDate(String blockedId) =>
      _blocked.doc(blockedId).delete();
}
