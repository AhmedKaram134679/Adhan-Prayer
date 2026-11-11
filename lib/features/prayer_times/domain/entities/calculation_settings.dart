import 'package:flutter/foundation.dart';

enum CalculationMethodMode {
  automatic,
  manual,
}

enum CalculationMethodType {
  muslimWorldLeague,
  egyptian,
  karachi,
  ummAlQura,
  dubai,
  qatar,
  kuwait,
  moonsightingCommittee,
  northAmerica,
}

enum MadhabType {
  shafi,
  hanafi,
}

@immutable
class CalculationSettings {
  final CalculationMethodMode mode;
  final CalculationMethodType method;
  final MadhabType madhab;

  const CalculationSettings({
    this.mode = CalculationMethodMode.automatic,
    this.method = CalculationMethodType.egyptian,
    this.madhab = MadhabType.shafi,
  });

  CalculationSettings copyWith({
    CalculationMethodMode? mode,
    CalculationMethodType? method,
    MadhabType? madhab,
  }) {
    return CalculationSettings(
      mode: mode ?? this.mode,
      method: method ?? this.method,
      madhab: madhab ?? this.madhab,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'method': method.name,
    'madhab': madhab.name,
  };

  factory CalculationSettings.fromJson(Map<String, dynamic> json) {
    final modeStr = json['mode'];
    final CalculationMethodMode mode = modeStr != null
        ? CalculationMethodMode.values.firstWhere(
            (e) => e.name == modeStr,
            orElse: () => CalculationMethodMode.automatic,
          )
        : (json['method'] != null && json['method'] != 'egyptian'
            ? CalculationMethodMode.manual
            : CalculationMethodMode.automatic);

    return CalculationSettings(
      mode: mode,
      method: CalculationMethodType.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => CalculationMethodType.egyptian,
      ),
      madhab: MadhabType.values.firstWhere(
        (e) => e.name == json['madhab'],
        orElse: () => MadhabType.shafi,
      ),
    );
  }
}
