import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/call_record.dart';
import '../database/database_helper.dart';
import '../services/api_service.dart';

class CallProvider with ChangeNotifier {
  static const _channel = MethodChannel('com.qizongyun.phoneapp/call_recorder');

  // iOS / 降级方案
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isInCall = false;
  bool _usingNativeRecorder = false;
  String? _currentRecordingPath;
  DateTime? _callStartTime;
  String? _currentPhoneNumber;
  String? _currentContactName;
  String _recordingMode = '';

  bool get isRecording => _isRecording;
  bool get isInCall => _isInCall;
  String get recordingMode => _recordingMode;

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
    _currentRecordingPath = null;
    _usingNativeRecorder = false;
    _recordingMode = '';
    notifyListeners();
  }

  /// 在 CallScreen 渲染完成后调用
  /// [delaySeconds] 延迟几秒再开始录，等待通话真正接通
  Future<void> startRecording({int delaySeconds = 2}) async {
    if (_isRecording) return;

    // 关键：延迟等待通话接通，否则音频路由还没切换到电话模式
    if (delaySeconds > 0) {
      await Future.delayed(Duration(seconds: delaySeconds));
    }

    // 延迟后再检查是否还在通话中
    if (!_isInCall) return;

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (Platform.isAndroid) {
      await _startAndroidRecording(directory.path, timestamp);
    } else {
      await _startIosFallback(directory.path, timestamp);
    }
  }

  Future<void> _startAndroidRecording(String dirPath, int timestamp) async {
    // 路径先给 .wav，原生层会根据实际选择的方案决定用 .m4a 还是 .wav
    final wavPath = '$dirPath/recording_$timestamp.wav';

    try {
      final success = await _channel.invokeMethod<bool>(
        'startCallRecording',
        {'path': wavPath},
      );

      if (success == true) {
        // 原生层可能把路径改为 .m4a，查询实际路径
        // 先假设是 .m4a（MediaRecorder 优先），若不存在再用 .wav
        final m4aPath = wavPath.replaceAll('.wav', '.m4a');
        _currentRecordingPath = m4aPath; // 原生层内部会覆盖为正确路径

        _isRecording = true;
        _usingNativeRecorder = true;

        // 查询实际录音模式（用于调试）
        try {
          final mode = await _channel.invokeMethod<String>('getRecordingMode');
          _recordingMode = mode ?? 'unknown';
          debugPrint('录音模式: $_recordingMode');
        } catch (_) {}

        debugPrint('Android 原生录音已开始');
        notifyListeners();
      } else {
        debugPrint('原生录音返回 false，降级');
        await _startAndroidFallback(dirPath, timestamp);
      }
    } catch (e) {
      debugPrint('原生录音异常: $e，降级');
      await _startAndroidFallback(dirPath, timestamp);
    }
  }

  /// Android 降级：用 record 包录麦克风
  Future<void> _startAndroidFallback(String dirPath, int timestamp) async {
    final path = '$dirPath/recording_${timestamp}_fallback.m4a';
    try {
      if (!await _recorder.hasPermission()) return;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _isRecording = true;
      _usingNativeRecorder = false;
      _currentRecordingPath = path;
      _recordingMode = 'fallback_mic';
      debugPrint('Android 降级录音（麦克风）已开始');
      notifyListeners();
    } catch (e) {
      debugPrint('降级录音失败: $e');
    }
  }

  /// iOS 只能录麦克风
  Future<void> _startIosFallback(String dirPath, int timestamp) async {
    final path = '$dirPath/recording_$timestamp.m4a';
    try {
      if (!await _recorder.hasPermission()) return;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _isRecording = true;
      _usingNativeRecorder = false;
      _currentRecordingPath = path;
      _recordingMode = 'ios_mic';
      debugPrint('iOS 麦克风录音已开始');
      notifyListeners();
    } catch (e) {
      debugPrint('iOS 录音失败: $e');
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      if (_usingNativeRecorder) {
        final finalPath =
        await _channel.invokeMethod<String>('stopCallRecording');
        // 原生层返回实际写入的路径（可能是 .m4a 或 .wav）
        if (finalPath != null && finalPath.isNotEmpty) {
          _currentRecordingPath = finalPath;
        }
        debugPrint('原生录音停止，最终路径: $_currentRecordingPath');
      } else {
        final stoppedPath = await _recorder.stop();
        if (stoppedPath != null && stoppedPath.isNotEmpty) {
          _currentRecordingPath = stoppedPath;
        }
        debugPrint('降级录音停止，最终路径: $_currentRecordingPath');
      }
    } catch (e) {
      debugPrint('停止录音失败: $e');
    } finally {
      _isRecording = false;
      _usingNativeRecorder = false;
      notifyListeners();
    }
  }

  Future<void> endCall() async {
    if (!_isInCall) return;

    if (_isRecording) {
      await stopRecording();
    }

    // 给原生线程充足时间完成 PCM→WAV 转换
    await Future.delayed(const Duration(seconds: 1));

    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!).inSeconds
        : 0;

    // 验证文件：存在 + 大于 4KB（WAV/M4A 头部约 44/~4096 bytes）
    String? validRecordingPath;
    if (_currentRecordingPath != null) {
      // 可能是 .m4a 或 .wav，都检查一遍
      final candidates = [
        _currentRecordingPath!,
        _currentRecordingPath!.replaceAll('.wav', '.m4a'),
        _currentRecordingPath!.replaceAll('.m4a', '.wav'),
      ];

      for (final candidate in candidates) {
        final file = File(candidate);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('检查录音文件: $candidate，大小: $size bytes');
          if (size > 4096) {
            validRecordingPath = candidate;
            break;
          } else {
            debugPrint('文件过小（$size bytes），丢弃');
            try { await file.delete(); } catch (_) {}
          }
        }
      }
    }

    if (validRecordingPath == null) {
      debugPrint('未找到有效录音文件，录音模式: $_recordingMode');
    }

    final record = CallRecord(
      phoneNumber: _currentPhoneNumber ?? '',
      contactName: _currentContactName,
      duration: duration,
      recordingPath: validRecordingPath,
      timestamp: _callStartTime ?? DateTime.now(),
    );

    final id = await DatabaseHelper.instance.insertCallRecord(record);

    if (validRecordingPath != null) {
      await uploadRecording(validRecordingPath, id);
    }

    _isInCall = false;
    _currentPhoneNumber = null;
    _currentContactName = null;
    _callStartTime = null;
    _currentRecordingPath = null;
    _recordingMode = '';

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