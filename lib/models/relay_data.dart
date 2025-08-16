enum RelayStatus { off, on, timer, timeUp }

class RelayData {
  final int id;
  RelayStatus status;
  int remainingTimeSeconds;
  DateTime? timerEndTime;
  bool fiveMinuteWarningSent;

  RelayData({
    required this.id,
    this.status = RelayStatus.off,
    this.remainingTimeSeconds = 0,
    this.timerEndTime,
    this.fiveMinuteWarningSent = false,
  });
}