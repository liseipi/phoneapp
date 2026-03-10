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
    // 在界面渲染完成后再启动录音，确保 Provider 已就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  Future<void> _startRecording() async {
    if (!mounted) return;
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    await callProvider.startRecording();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration() {
    final minutes = _seconds ~/ 60;
    final seconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    await callProvider.endCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // 联系人/号码显示
            Text(
              widget.contactName ?? widget.phoneNumber,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.contactName != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.phoneNumber,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade700,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 通话时长
            Text(
              _formatDuration(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 40),

            // 录音状态指示器
            Consumer<CallProvider>(
              builder: (context, callProvider, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: callProvider.isRecording
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        callProvider.isRecording
                            ? Icons.fiber_manual_record
                            : Icons.mic_off,
                        color: callProvider.isRecording
                            ? Colors.red
                            : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        callProvider.isRecording ? '正在录音...' : '录音准备中...',
                        style: TextStyle(
                          color: callProvider.isRecording
                              ? Colors.red.shade900
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Spacer(),

            // 控制按钮
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCallButton(
                        icon: Icons.mic_off,
                        label: '静音',
                        onPressed: () {},
                      ),
                      _buildCallButton(
                        icon: Icons.dialpad,
                        label: '拨号键盘',
                        onPressed: () {},
                      ),
                      _buildCallButton(
                        icon: Icons.volume_up,
                        label: '扬声器',
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),

                  // 挂断按钮
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

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
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
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}