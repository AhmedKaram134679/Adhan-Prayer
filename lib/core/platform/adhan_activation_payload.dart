import 'dart:convert';

/// Structured payload representing a notification activation event
/// requesting that the application restore and display the Adhan dialog.
class AdhanActivationPayload {
  static const String cliFlag = '--activate-adhan';

  final String source;
  final String prayerName;
  final String eventId;
  final String? sessionId;
  final int? controlPort;

  const AdhanActivationPayload({
    required this.source,
    required this.prayerName,
    required this.eventId,
    this.sessionId,
    this.controlPort,
  });

  factory AdhanActivationPayload.create({
    required String source,
    required String prayerName,
    String? eventId,
    String? sessionId,
    int? controlPort,
  }) {
    final sanitizedPrayer = prayerName.trim().isEmpty ? 'Prayer' : prayerName.trim();
    final generatedId = eventId != null && eventId.trim().isNotEmpty
        ? eventId.trim()
        : '${source}_${sanitizedPrayer}_${DateTime.now().millisecondsSinceEpoch}';
    return AdhanActivationPayload(
      source: source,
      prayerName: sanitizedPrayer,
      eventId: generatedId,
      sessionId: sessionId?.trim().isNotEmpty == true ? sessionId!.trim() : null,
      controlPort: (controlPort != null && controlPort > 0) ? controlPort : null,
    );
  }

  bool get hasHeadlessControl =>
      sessionId != null &&
      sessionId!.isNotEmpty &&
      controlPort != null &&
      controlPort! > 0;

  Map<String, dynamic> toJson() => {
        'source': source,
        'prayerName': prayerName,
        'eventId': eventId,
        if (sessionId != null) 'sessionId': sessionId,
        if (controlPort != null) 'controlPort': controlPort,
      };

  String toJsonString() => jsonEncode(toJson());

  List<String> toCliArgs() => [cliFlag, toJsonString()];

  static AdhanActivationPayload? fromJson(Map<String, dynamic> json) {
    final source = json['source'];
    final prayerName = json['prayerName'];
    final eventId = json['eventId'];
    if (source is! String || source.trim().isEmpty) return null;
    if (prayerName is! String || prayerName.trim().isEmpty) return null;
    if (eventId is! String || eventId.trim().isEmpty) return null;

    final rawSessionId = json['sessionId'];
    final rawControlPort = json['controlPort'];

    return AdhanActivationPayload(
      source: source.trim(),
      prayerName: prayerName.trim(),
      eventId: eventId.trim(),
      sessionId: rawSessionId is String && rawSessionId.trim().isNotEmpty
          ? rawSessionId.trim()
          : null,
      controlPort: rawControlPort is int && rawControlPort > 0
          ? rawControlPort
          : null,
    );
  }

  static AdhanActivationPayload? fromJsonString(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return fromJson(decoded);
      }
      if (decoded is Map) {
        return fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static AdhanActivationPayload? fromCliArgs(List<String> args) {
    final flagIndex = args.indexOf(cliFlag);
    if (flagIndex == -1 || flagIndex + 1 >= args.length) {
      return null;
    }
    return fromJsonString(args[flagIndex + 1]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdhanActivationPayload &&
        other.source == source &&
        other.prayerName == prayerName &&
        other.eventId == eventId &&
        other.sessionId == sessionId &&
        other.controlPort == controlPort;
  }

  @override
  int get hashCode =>
      Object.hash(source, prayerName, eventId, sessionId, controlPort);

  @override
  String toString() =>
      'AdhanActivationPayload(source: $source, prayerName: $prayerName, eventId: $eventId, sessionId: $sessionId, controlPort: $controlPort)';
}
