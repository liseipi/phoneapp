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
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录音文件不存在')),
          );
        }
        return;
      }

      await _audioPlayer.setFilePath(widget.recordingPath);

      _audioPlayer.durationStream.listen((duration) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      });

      _audioPlayer.positionStream.listen((position) {
        setState(() {
          _position = position;
        });
      });

      _audioPlayer.playerStateStream.listen((state) {
        setState(() {
          _isPlaying = state.playing;
        });
      });
    } catch (e) {
      debugPrint('初始化播放器失败: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
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
      appBar: AppBar(
        title: const Text('播放录音'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 联系人信息
            Icon(
              Icons.mic,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              widget.contactName ?? widget.phoneNumber,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.contactName != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.phoneNumber,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 60),

            // 进度条
            Column(
              children: [
                Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) async {
                    await _audioPlayer.seek(Duration(seconds: value.toInt()));
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
                  onPressed: () async {
                    final newPosition = _position - const Duration(seconds: 10);
                    await _audioPlayer.seek(
                      newPosition < Duration.zero ? Duration.zero : newPosition,
                    );
                  },
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
                  onPressed: () async {
                    final newPosition = _position + const Duration(seconds: 10);
                    await _audioPlayer.seek(
                      newPosition > _duration ? _duration : newPosition,
                    );
                  },
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
                    const Text(
                      '录音文件信息',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('文件路径: ${widget.recordingPath}'),
                    Text('时长: ${_formatDuration(_duration)}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
