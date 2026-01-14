class CookingStep {
  final String description;
  final int? timerSeconds;

  CookingStep({
    required this.description,
    this.timerSeconds,
  });

  bool get hasTimer => timerSeconds != null && timerSeconds! > 0;

  String get timerDisplay {
    if (!hasTimer) return '';

    final minutes = timerSeconds! ~/ 60;
    final seconds = timerSeconds! % 60;

    if (minutes > 0 && seconds > 0) {
      return '$minutes分$seconds秒';
    } else if (minutes > 0) {
      return '$minutes分';
    } else {
      return '$seconds秒';
    }
  }

  CookingStep copyWith({
    String? description,
    int? timerSeconds,
  }) {
    return CookingStep(
      description: description ?? this.description,
      timerSeconds: timerSeconds ?? this.timerSeconds,
    );
  }
}
