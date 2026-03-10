import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../providers/call_provider.dart';
import 'call_screen.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _phoneNumber = '';

  void _addDigit(String digit) {
    setState(() {
      _phoneNumber += digit;
    });
  }

  void _deleteDigit() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  void _clearNumber() {
    setState(() {
      _phoneNumber = '';
    });
  }

  Future<void> _makeCall() async {
    if (_phoneNumber.isEmpty) return;

    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // 导航到通话界面
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(phoneNumber: _phoneNumber),
      ),
    );

    // 启动通话
    await callProvider.startCall(_phoneNumber);
    
    // 实际拨打电话
    await FlutterPhoneDirectCaller.callNumber(_phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拨号'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 电话号码显示区域
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _phoneNumber.isEmpty ? '输入号码' : _phoneNumber,
                    style: TextStyle(
                      fontSize: _phoneNumber.isEmpty ? 24 : 32,
                      fontWeight: FontWeight.w400,
                      color: _phoneNumber.isEmpty
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (_phoneNumber.isNotEmpty)
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 拨号键盘
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDialRow(['1', '2', '3']),
                  _buildDialRow(['4', '5', '6']),
                  _buildDialRow(['7', '8', '9']),
                  _buildDialRow(['*', '0', '#']),
                ],
              ),
            ),
          ),

          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 删除按钮
                IconButton(
                  onPressed: _phoneNumber.isNotEmpty ? _deleteDigit : null,
                  icon: const Icon(Icons.backspace_outlined),
                  iconSize: 28,
                ),
                // 拨打按钮
                FloatingActionButton(
                  onPressed: _phoneNumber.isNotEmpty ? _makeCall : null,
                  backgroundColor: _phoneNumber.isNotEmpty
                      ? Colors.green
                      : Colors.grey,
                  child: const Icon(Icons.phone, size: 32),
                ),
                // 清空按钮
                IconButton(
                  onPressed: _phoneNumber.isNotEmpty ? _clearNumber : null,
                  icon: const Icon(Icons.clear),
                  iconSize: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) => _buildDialButton(digit)).toList(),
    );
  }

  Widget _buildDialButton(String digit) {
    return InkWell(
      onTap: () => _addDigit(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 75,
        height: 75,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
