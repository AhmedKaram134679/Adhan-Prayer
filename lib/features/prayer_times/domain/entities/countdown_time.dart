import 'package:flutter/foundation.dart';

@immutable
class CountdownTime {
  final int hours;
  final int minutes;
  final int seconds;
  final bool isDue;

  const CountdownTime({
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.isDue = false,
  });

  factory CountdownTime.fromDuration(Duration duration) {
    if (duration.isNegative || duration.inSeconds <= 0) {
      return const CountdownTime(hours: 0, minutes: 0, seconds: 0, isDue: true);
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return CountdownTime(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      isDue: false,
    );
  }

  String formatFormatted() {
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
