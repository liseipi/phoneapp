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

  /// 仅更新通话状态，不自动录音（由UI在合适时机调用startRecording）
  Future<void> startCall(String phoneNumber, {String? contactName}) async {
    _isInCall = true;
    _currentPhoneNumber = phoneNumber;
    _currentContactName = contactName;
    _callStartTime = DateTime.now();
    _currentRecordingPath = null;
    notifyListeners();
  }

  Future<void> startRecording() async {
    // 避免重复录音
    if (_isRecording) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('没有录音权限');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/recording_$timestamp.m4a';

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
      debugPrint('录音已开始，路径: $path');
      notifyListeners();
    } catch (e) {
      debugPrint('录音启动失败: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      // stop() 返回实际写入的文件路径，以此为准
      if (path != null && path.isNotEmpty) {
        _currentRecordingPath = path;
        debugPrint('录音已停止，文件: $path');
      } else {
        debugPrint('录音停止后路径为空，使用预设路径: $_currentRecordingPath');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('停止录音失败: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> endCall() async {
    if (!_isInCall) return;

    // 先停止录音
    if (_isRecording) {
      await stopRecording();
    }

    // 计算通话时长
    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!).inSeconds
        : 0;

    // 验证录音文件是否真实存在且有内容
    String? validRecordingPath;
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        final size = await file.length();
        debugPrint('录音文件大小: $size bytes');
        if (size > 1024) {
          // 文件至少 1KB 才认为有效
          validRecordingPath = _currentRecordingPath;
        } else {
          debugPrint('录音文件过小（$size bytes），可能录音失败');
          // 删除无效文件
          try {
            await file.delete();
          } catch (_) {}
        }
      } else {
        debugPrint('录音文件不存在: $_currentRecordingPath');
      }
    }

    // 保存通话记录
    final record = CallRecord(
      phoneNumber: _currentPhoneNumber ?? '',
      contactName: _currentContactName,
      duration: duration,
      recordingPath: validRecordingPath,
      timestamp: _callStartTime ?? DateTime.now(),
    );

    final id = await DatabaseHelper.instance.insertCallRecord(record);

    // 如果有有效录音，上传到API
    if (validRecordingPath != null) {
      await uploadRecording(validRecordingPath, id);
    }

    // 重置状态
    _isInCall = false;
    _currentPhoneNumber = null;
    _currentContactName = null;
    _callStartTime = null;
    _currentRecordingPath = null;

    await loadCallRecords();
    notifyListeners();
  }

  Future<void> uploadRecording(String filePath, int recordId) async {
    try {
      final success = await ApiService.uploadRecording(filePath, recordId);
      debugPrint(success ? '录音上传成功' : '录音上传失败');
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