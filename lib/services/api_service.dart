import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://your-api-server.com/api', // 替换为你的API地址
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// 上传录音文件
  static Future<bool> uploadRecording(String filePath, int recordId) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('文件不存在: $filePath');
        return false;
      }

      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
        'record_id': recordId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final response = await _dio.post(
        '/recordings/upload',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).toStringAsFixed(0);
          debugPrint('上传进度: $progress%');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('录音上传成功');
        return true;
      } else {
        debugPrint('上传失败: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      debugPrint('Dio错误: ${e.message}');
      if (e.response != null) {
        debugPrint('响应数据: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      debugPrint('上传录音时出错: $e');
      return false;
    }
  }

  /// 获取录音列表（可选功能）
  static Future<List<dynamic>> getRecordings() async {
    try {
      final response = await _dio.get('/recordings');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('获取录音列表失败: $e');
      return [];
    }
  }

  /// 删除云端录音（可选功能）
  static Future<bool> deleteRecording(int recordId) async {
    try {
      final response = await _dio.delete('/recordings/$recordId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('删除录音失败: $e');
      return false;
    }
  }
}
