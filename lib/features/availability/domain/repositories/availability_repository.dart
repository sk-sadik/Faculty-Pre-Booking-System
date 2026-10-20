import '../entities/availability.dart';

/// Params for creating/updating a weekly or one-off availability rule.
class AvailabilityInput {
  const AvailabilityInput({
    this.dayOfWeek,
    this.specificDate,
    required this.startTime,
    required this.endTime,
    required this.slotDuration,
    this.isActive = true,
  });

  final int? dayOfWeek;
  final String? specificDate;
  final String startTime;
  final String endTime;
  final int slotDuration;
  final bool isActive;

  Map<String, dynamic> toMap(String facultyId) => {
        'facultyId': facultyId,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (specificDate != null) 'specificDate': specificDate,
        'startTime': startTime,
        'endTime': endTime,
        'slotDuration': slotDuration,
        'isActive': isActive,
      };
}

abstract class AvailabilityRepository {
  Stream<List<AvailabilityRule>> watchRules(String facultyId);
  Stream<List<BlockedDate>> watchBlockedDates(String facultyId);

  Future<String> addRule(String facultyId, AvailabilityInput input);
  Future<void> updateRule(String ruleId, Map<String, dynamic> patch);
  Future<void> toggleRule(String ruleId, bool isActive);
  Future<void> deleteRule(String ruleId);

  Future<String> blockDate(
      String facultyId, String dateKey, String reason);
  Future<void> unblockDate(String blockedId);
}
