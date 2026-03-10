package com.qizongyun.phoneapp.newapp

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.qizongyun.phoneapp/call_recorder"

    // 使用两路录音同时进行，取有声音的那路
    private var audioRecord: AudioRecord? = null
    private var mediaRecorder: MediaRecorder? = null

    private var isRecording = false
    private var recordingThread: Thread? = null
    private var outputFilePath: String? = null

    // 记录实际使用的录音方式，方便调试
    private var recordingMode = "none"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCallRecording" -> {
                        val path = call.argument<String>("path") ?: run {
                            result.error("INVALID_PATH", "路径不能为空", null)
                            return@setMethodCallHandler
                        }
                        val success = startCallRecording(path)
                        result.success(success)
                    }
                    "stopCallRecording" -> {
                        val finalPath = stopCallRecording()
                        result.success(finalPath)
                    }
                    "getRecordingMode" -> {
                        result.success(recordingMode)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startCallRecording(path: String): Boolean {
        if (isRecording) return false
        outputFilePath = path

        // 优先尝试 MediaRecorder（更稳定，系统内置编解码）
        // 路径改为 .m4a，MediaRecorder 输出 AAC
        val m4aPath = path.replace(".wav", ".m4a")
        outputFilePath = m4aPath

        if (tryMediaRecorder(m4aPath)) {
            isRecording = true
            recordingMode = "MediaRecorder"
            android.util.Log.d("CallRecorder", "使用 MediaRecorder 录音，路径: $m4aPath")
            return true
        }

        // MediaRecorder 失败，降级到 AudioRecord + WAV
        outputFilePath = path
        if (tryAudioRecord(path)) {
            isRecording = true
            recordingMode = "AudioRecord"
            android.util.Log.d("CallRecorder", "使用 AudioRecord 录音，路径: $path")
            return true
        }

        recordingMode = "failed"
        android.util.Log.e("CallRecorder", "所有录音方式均失败")
        return false
    }

    // ── MediaRecorder 方案 ──────────────────────────────────────────────────

    private fun tryMediaRecorder(path: String): Boolean {
        // 按优先级尝试各音频源
        // VOICE_CALL      = 4  → 双方通话（需要系统权限，部分设备支持）
        // VOICE_DOWNLINK  = 6  → 仅对方声音（部分 ROM 支持）
        // VOICE_UPLINK    = 5  → 仅自己声音
        // MIC             = 1  → 麦克风兜底
        val sources = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            intArrayOf(
                MediaRecorder.AudioSource.VOICE_CALL,
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.MIC
            )
        } else {
            // Android 10+ VOICE_CALL 基本无效，直接用 VOICE_COMMUNICATION
            intArrayOf(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.MIC
            )
        }

        for (source in sources) {
            try {
                val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(this)
                } else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }

                mr.apply {
                    setAudioSource(source)
                    setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    setAudioSamplingRate(44100)
                    setAudioEncodingBitRate(128000)
                    setAudioChannels(1)
                    setOutputFile(path)
                    prepare()
                    start()
                }

                mediaRecorder = mr
                android.util.Log.d("CallRecorder", "MediaRecorder 启动成功，audioSource=$source")
                return true
            } catch (e: Exception) {
                android.util.Log.w("CallRecorder", "MediaRecorder source=$source 失败: ${e.message}")
                try { mediaRecorder?.release() } catch (_: Exception) {}
                mediaRecorder = null
                // 删除可能产生的残留文件
                try { File(path).delete() } catch (_: Exception) {}
            }
        }
        return false
    }

    // ── AudioRecord 方案（PCM → WAV）────────────────────────────────────────

    private fun tryAudioRecord(path: String): Boolean {
        val sampleRate = 44100
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBuf = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        val bufferSize = minBuf * 4  // 给足缓冲，减少丢帧

        val sources = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            intArrayOf(
                MediaRecorder.AudioSource.VOICE_CALL,
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.MIC
            )
        } else {
            intArrayOf(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.MIC
            )
        }

        for (source in sources) {
            try {
                val ar = AudioRecord(source, sampleRate, channelConfig, audioFormat, bufferSize)
                if (ar.state == AudioRecord.STATE_INITIALIZED) {
                    audioRecord = ar
                    android.util.Log.d("CallRecorder", "AudioRecord 初始化成功，source=$source")
                    startAudioRecordThread(path, sampleRate)
                    return true
                } else {
                    ar.release()
                }
            } catch (e: Exception) {
                android.util.Log.w("CallRecorder", "AudioRecord source=$source 失败: ${e.message}")
            }
        }
        return false
    }

    private fun startAudioRecordThread(wavPath: String, sampleRate: Int) {
        val pcmPath = "$wavPath.pcm"
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ) * 4

        recordingThread = thread(start = true) {
            val buffer = ByteArray(bufferSize)
            var totalBytes = 0L
            var silentFrames = 0
            var fos: FileOutputStream? = null

            try {
                fos = FileOutputStream(File(pcmPath))
                audioRecord?.startRecording()

                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: break
                    if (read > 0) {
                        fos.write(buffer, 0, read)
                        totalBytes += read

                        // 静音检测：计算 RMS，连续静音超过 3 秒打印警告
                        val rms = calculateRms(buffer, read)
                        if (rms < 50) silentFrames++ else silentFrames = 0
                        if (silentFrames > 150) { // ~3秒静音
                            android.util.Log.w("CallRecorder", "警告：连续静音，可能未录到通话声音")
                            silentFrames = 0
                        }
                    }
                }
            } catch (e: IOException) {
                android.util.Log.e("CallRecorder", "写入 PCM 失败: ${e.message}")
            } finally {
                fos?.flush()
                fos?.close()
            }

            android.util.Log.d("CallRecorder", "录音结束，总字节: $totalBytes")

            // PCM → WAV
            if (totalBytes > 0) {
                try {
                    pcmToWav(pcmPath, wavPath, sampleRate, 1, 16)
                    File(pcmPath).delete()
                    android.util.Log.d("CallRecorder", "PCM 转 WAV 成功")
                } catch (e: Exception) {
                    android.util.Log.e("CallRecorder", "PCM 转 WAV 失败: ${e.message}")
                    File(pcmPath).renameTo(File(wavPath))
                }
            } else {
                android.util.Log.e("CallRecorder", "录音数据为空，删除空文件")
                File(pcmPath).delete()
            }
        }
    }

    private fun calculateRms(buffer: ByteArray, length: Int): Double {
        var sum = 0.0
        var i = 0
        while (i < length - 1) {
            // PCM 16-bit little-endian
            val sample = (buffer[i].toInt() and 0xFF) or (buffer[i + 1].toInt() shl 8)
            sum += sample.toDouble() * sample.toDouble()
            i += 2
        }
        return sqrt(sum / (length / 2))
    }

    // ── 停止录音 ────────────────────────────────────────────────────────────

    private fun stopCallRecording(): String? {
        isRecording = false

        // 停止 MediaRecorder
        if (mediaRecorder != null) {
            try {
                mediaRecorder?.stop()
            } catch (e: Exception) {
                android.util.Log.e("CallRecorder", "MediaRecorder stop 失败: ${e.message}")
                // stop() 失败时文件可能损坏，删掉
                outputFilePath?.let { try { File(it).delete() } catch (_: Exception) {} }
                outputFilePath = null
            } finally {
                try { mediaRecorder?.release() } catch (_: Exception) {}
                mediaRecorder = null
            }
        }

        // 停止 AudioRecord
        if (audioRecord != null) {
            try {
                audioRecord?.stop()
                audioRecord?.release()
            } catch (e: Exception) {
                android.util.Log.e("CallRecorder", "AudioRecord stop 失败: ${e.message}")
            } finally {
                audioRecord = null
            }
            // 等待写文件线程完成（最多 5 秒）
            recordingThread?.join(5000)
            recordingThread = null
        }

        android.util.Log.d("CallRecorder", "录音已停止，文件: $outputFilePath，模式: $recordingMode")
        return outputFilePath
    }

    // ── PCM → WAV ──────────────────────────────────────────────────────────

    @Throws(IOException::class)
    private fun pcmToWav(pcmPath: String, wavPath: String, sampleRate: Int, channels: Int, bitDepth: Int) {
        val pcmFile = File(pcmPath)
        val pcmSize = pcmFile.length()
        val byteRate = sampleRate * channels * bitDepth / 8

        FileOutputStream(File(wavPath)).use { out ->
            val header = ByteBuffer.allocate(44).apply {
                order(ByteOrder.LITTLE_ENDIAN)
                put("RIFF".toByteArray())
                putInt((36 + pcmSize).toInt())
                put("WAVE".toByteArray())
                put("fmt ".toByteArray())
                putInt(16)
                putShort(1)
                putShort(channels.toShort())
                putInt(sampleRate)
                putInt(byteRate)
                putShort((channels * bitDepth / 8).toShort())
                putShort(bitDepth.toShort())
                put("data".toByteArray())
                putInt(pcmSize.toInt())
            }
            out.write(header.array())
            pcmFile.inputStream().use { it.copyTo(out) }
        }
    }
}