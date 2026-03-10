import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/call_provider.dart';
import '../models/call_record.dart';
import 'recording_player_screen.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通话记录'),
        centerTitle: true,
      ),
      body: Consumer<CallProvider>(
        builder: (context, callProvider, child) {
          if (callProvider.callRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无通话记录',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: callProvider.callRecords.length,
            itemBuilder: (context, index) {
              final record = callProvider.callRecords[index];
              return _CallRecordTile(
                record: record,
                onDelete: () => callProvider.deleteCallRecord(record.id!),
              );
            },
          );
        },
      ),
    );
  }
}

class _CallRecordTile extends StatelessWidget {
  final CallRecord record;
  final VoidCallback onDelete;

  const _CallRecordTile({
    required this.record,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return '昨天 ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('E HH:mm', 'zh_CN').format(date);
    } else {
      return DateFormat('MM/dd HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(record.id.toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.phone,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          record.contactName ?? record.phoneNumber,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.contactName != null)
              Text(record.phoneNumber),
            Text(
              '时长: ${record.formattedDuration} • ${_formatDate(record.timestamp)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: record.recordingPath != null
            ? IconButton(
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordingPlayerScreen(
                        recordingPath: record.recordingPath!,
                        phoneNumber: record.phoneNumber,
                        contactName: record.contactName,
                      ),
                    ),
                  );
                },
              )
            : null,
        onTap: () {
          // 可以添加重新拨打功能
        },
      ),
    );
  }
}
