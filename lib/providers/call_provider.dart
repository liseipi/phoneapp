import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/call_record.dart';
import '../database/database_helper.dart';
import '../services/api_service.dart';

class CallProvider with ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isInCall = false;
  String? _currentRecordingPath;
  DateTime? _callStartTime;
  String? _currentPhoneNumber;
  String? _currentContactName;

  bool get isRecording => _isRecording;
  bool get isInCall => _isInCall;
  List<CallRecord> _callRecords = [];
  List<CallRecord> get callRecords => _callRecords;

  CallProvider() {
    loadCallRecords();
  }

  Future<void> loadCallRecords() async {
    _callRecords = await DatabaseHelper.instance.getAllCallRecords();
    notifyListeners();
  }

  Future<void> startCall(String phoneNumber, {String? contactName}) async {
    _isInCall = true;
    _currentPhoneNumber = phoneNumber;
    _currentContactName = contactName;
    _callStartTime = DateTime.now();
    notifyListeners();

    // 自动开始录音
    await startRecording();
  }

  Future<void> startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/recording_$timestamp.m4a';

      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );
        _isRecording = true;
        _currentRecordingPath = path;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('录音启动失败: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      await _recorder.stop();
      _isRecording = false;
      notifyListeners();
    } catch (e) {
      debugPrint('停止录音失败: $e');
    }
  }

  Future<void> endCall() async {
    if (!_isInCall) return;

    // 停止录音
    if (_isRecording) {
      await stopRecording();
    }

    // 计算通话时长
    final duration = DateTime.now().difference(_callStartTime!).inSeconds;

    // 保存通话记录
    final record = CallRecord(
      phoneNumber: _currentPhoneNumber!,
      contactName: _currentContactName,
      duration: duration,
      recordingPath: _currentRecordingPath,
      timestamp: _callStartTime!,
    );

    final id = await DatabaseHelper.instance.insertCallRecord(record);

    // 如果有录音，上传到API
    if (_currentRecordingPath != null && File(_currentRecordingPath!).existsSync()) {
      await uploadRecording(_currentRecordingPath!, id);
    }

    // 重置状态
    _isInCall = false;
    _currentPhoneNumber = null;
    _currentContactName = null;
    _callStartTime = null;
    _currentRecordingPath = null;

    // 重新加载通话记录
    await loadCallRecords();
    notifyListeners();
  }

  Future<void> uploadRecording(String filePath, int recordId) async {
    try {
      final success = await ApiService.uploadRecording(filePath, recordId);
      if (success) {
        debugPrint('录音上传成功');
      } else {
        debugPrint('录音上传失败');
      }
    } catch (e) {
      debugPrint('上传录音时出错: $e');
    }
  }

  Future<void> deleteCallRecord(int id) async {
    await DatabaseHelper.instance.deleteCallRecord(id);
    await loadCallRecords();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
