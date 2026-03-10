import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

class RecordingPlayerScreen extends StatefulWidget {
  final String recordingPath;
  final String phoneNumber;
  final String? contactName;

  const RecordingPlayerScreen({
    super.key,
    required this.recordingPath,
    required this.phoneNumber,
    this.contactName,
  });

  @override
  State<RecordingPlayerScreen> createState() => _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends State<RecordingPlayerScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final file = File(widget.recordingPath);
      final exists = await file.exists();

      if (!exists) {
        setState(() {
          _hasError = true;
          _errorMessage = '录音文件不存在';
          _isLoading = false;
        });
        return;
      }

      final fileSize = await file.length();
      debugPrint('播放文件: ${widget.recordingPath}, 大小: $fileSize bytes');

      if (fileSize < 100) {
        setState(() {
          _hasError = true;
          _errorMessage = '录音文件无效（文件过小）';
          _isLoading = false;
        });
        return;
      }

      // 监听播放状态
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

      // 监听播放进度
      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      // 加载文件 —— setFilePath 返回后 duration 才可用
      final duration = await _audioPlayer.setFilePath(widget.recordingPath);

      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
          _isLoading = false;
        });
        debugPrint('音频时长: $_duration');
      }
    } catch (e) {
      debugPrint('初始化播放器失败: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '播放器初始化失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // 如果播放到末尾，从头开始
        if (_position >= _duration && _duration > Duration.zero) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('播放/暂停失败: $e');
    }
  }

  Future<void> _seekBackward() async {
    final newPosition = _position - const Duration(seconds: 10);
    await _audioPlayer
        .seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  Future<void> _seekForward() async {
    final newPosition = _position + const Duration(seconds: 10);
    await _audioPlayer
        .seek(newPosition > _duration ? _duration : newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放录音')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 联系人信息
            Icon(Icons.mic,
                size: 100, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              widget.contactName ?? widget.phoneNumber,
              style:
              const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (widget.contactName != null) ...[
              const SizedBox(height: 8),
              Text(widget.phoneNumber,
                  style:
                  TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            ],

            const SizedBox(height: 60),

            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('加载录音中...'),
            ] else if (_hasError) ...[
              Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ] else ...[
              // 进度条
              Column(
                children: [
                  Slider(
                    value: _position.inMilliseconds
                        .toDouble()
                        .clamp(0.0, _duration.inMilliseconds.toDouble()),
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: (value) async {
                      await _audioPlayer
                          .seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position)),
                        Text(_formatDuration(_duration)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 播放控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.replay_10),
                    onPressed: _seekBackward,
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    onPressed: _togglePlayPause,
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.forward_10),
                    onPressed: _seekForward,
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // 文件信息
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('录音文件信息',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        '文件路径: ${widget.recordingPath}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      Text('时长: ${_formatDuration(_duration)}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}