class CallRecord {
  final int? id;
  final String phoneNumber;
  final String? contactName;
  final int duration; // 通话时长（秒）
  final String? recordingPath; // 录音文件路径
  final DateTime timestamp;

  CallRecord({
    this.id,
    required this.phoneNumber,
    this.contactName,
    required this.duration,
    this.recordingPath,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'contactName': contactName,
      'duration': duration,
      'recordingPath': recordingPath,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CallRecord.fromMap(Map<String, dynamic> map) {
    return CallRecord(
      id: map['id'] as int?,
      phoneNumber: map['phoneNumber'] as String,
      contactName: map['contactName'] as String?,
      duration: map['duration'] as int,
      recordingPath: map['recordingPath'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
