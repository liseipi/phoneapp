import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import 'dart:async';

class CallScreen extends StatefulWidget {
  final String phoneNumber;
  final String? contactName;

  const CallScreen({
    super.key,
    required this.phoneNumber,
    this.contactName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  Future<void> _startRecording() async {
    if (!mounted) return;
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    // 延迟 2 秒等通话接通，音频路由切换完成后再录
    await callProvider.startRecording(delaySeconds: 2);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration() {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    await callProvider.endCall();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Text(
              widget.contactName ?? widget.phoneNumber,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            if (widget.contactName != null) ...[
              const SizedBox(height: 8),
              Text(widget.phoneNumber,
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 20),
            Text(_formatDuration(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
            const SizedBox(height: 20),

            // 录音状态指示器
            Consumer<CallProvider>(
              builder: (context, cp, _) {
                final color = cp.isRecording ? Colors.red : Colors.grey;
                final bgColor =
                cp.isRecording ? Colors.red.shade100 : Colors.grey.shade200;
                String label;
                if (cp.isRecording) {
                  label = '● 录音中 (${cp.recordingMode})';
                } else if (cp.isInCall) {
                  label = '准备录音...';
                } else {
                  label = '未录音';
                }
                return Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(color: color, fontWeight: FontWeight.w500)),
                );
              },
            ),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBtn(Icons.mic_off, '静音', () {}),
                      _buildBtn(Icons.dialpad, '键盘', () {}),
                      _buildBtn(Icons.volume_up, '扬声器', () {}),
                    ],
                  ),
                  const SizedBox(height: 60),
                  FloatingActionButton(
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, size: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 32,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.3),
            padding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}