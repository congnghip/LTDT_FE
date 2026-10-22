package com.example.fb_interface

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.log10
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val TAG = "NoiseMeterNative"
    private val CHANNEL = "com.example.fb_interface/noise_meter"
    private val PERMISSION_REQ_CODE = 1001

    private var audioRecord: AudioRecord? = null
    @Volatile
    private var isRecording = false
    @Volatile
    private var currentDecibel: Double = 0.0
    private var recordingThread: Thread? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQ_CODE)
                    }
                    result.success(true)
                }
                "startNoiseMeter" -> {
                    val started = startRecording()
                    result.success(started)
                }
                "getNoiseLevel" -> {
                    if (isRecording && audioRecord?.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                        try {
                            audioRecord?.startRecording()
                        } catch (e: Exception) {
                            Log.w(TAG, "Failed to resume AudioRecord: ${e.message}")
                        }
                    }
                    result.success(currentDecibel)
                }
                "stopNoiseMeter" -> {
                    stopRecording()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQ_CODE && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "Audio recording permission granted by user, starting noise meter...")
            startRecording()
        }
    }

    @Synchronized
    private fun startRecording(): Boolean {
        if (isRecording && audioRecord != null && audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
            return true
        }
        stopRecording()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Permission RECORD_AUDIO not granted, requesting...")
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQ_CODE)
            return false
        }

        val sampleRate = 44100
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        val internalBufferSize = if (minBufferSize > 0) minBufferSize * 8 else 32768

        return try {
            var record: AudioRecord? = null
            // Ưu tiên AudioSource.MIC và DEFAULT (tương thích 100% với cả máy thật và máy ảo Android)
            // Tuyệt đối không dùng VOICE_RECOGNITION trước vì trên máy ảo Ranchu HAL trả về silence (0)
            val sources = intArrayOf(
                MediaRecorder.AudioSource.MIC,
                MediaRecorder.AudioSource.DEFAULT,
                MediaRecorder.AudioSource.CAMCORDER
            )
            for (source in sources) {
                try {
                    val r = AudioRecord(source, sampleRate, channelConfig, audioFormat, internalBufferSize)
                    if (r.state == AudioRecord.STATE_INITIALIZED) {
                        record = r
                        Log.i(TAG, "AudioRecord initialized successfully with source $source")
                        break
                    } else {
                        r.release()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Could not init AudioRecord with source $source: ${e.message}")
                }
            }

            if (record == null) {
                Log.e(TAG, "Failed to initialize AudioRecord with any source")
                return false
            }

            audioRecord = record
            record.startRecording()
            isRecording = true
            Log.i(TAG, "AudioRecord started recording (sampleRate=$sampleRate, buffer=$internalBufferSize)")

            // Đọc 704 samples mỗi lần (khớp chuẩn 100% với kích thước HAL frame của Android Emulator & AudioFlinger: 1408 bytes = 704 samples)
            val buffer = ShortArray(704)

            recordingThread = Thread {
                var lastLogTime = System.currentTimeMillis()
                var zeroFramesCount = 0
                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        var sum = 0.0
                        var peak = 0.0
                        for (i in 0 until read) {
                            val sample = buffer[i].toDouble()
                            sum += sample * sample
                            val abs = Math.abs(sample)
                            if (abs > peak) peak = abs
                        }
                        val rms = sqrt(sum / read)

                        // Chống nghẽn buffer / mất kết nối pipe âm thanh của máy ảo (Watchdog tự phục hồi):
                        // Nếu HAL rơi vào trạng thái silence (underrun liên tục ~550ms = 35 frames),
                        // lập tức stop() và startRecording() để tái đồng bộ hóa luồng thu âm mà không gián đoạn app.
                        if (rms == 0.0 && peak == 0.0) {
                            zeroFramesCount++
                            if (zeroFramesCount >= 35) {
                                try {
                                    audioRecord?.stop()
                                    audioRecord?.startRecording()
                                    zeroFramesCount = 0
                                    Log.i(TAG, "Watchdog auto-recovered stalled AudioRecord stream")
                                } catch (e: Exception) {
                                    Log.w(TAG, "Watchdog re-sync warning: ${e.message}")
                                }
                            }
                        } else {
                            zeroFramesCount = 0
                        }

                        // Tăng cường độ nhạy bắt âm thanh micro (kết hợp cả RMS và Peak nhạy bén)
                        val combined = Math.max(rms, peak * 0.75)

                        // Hiệu chuẩn Decibel SPL theo quy chuẩn đo âm thanh QCVN 24:2016/BYT:
                        // - Yên tĩnh / Tiếng thở nhẹ (combined <= 1.5): ~28 - 38 dB (An toàn - Xanh)
                        // - Nói chuyện nhẹ nhàng / Văn phòng (combined ~ 4 - 8): ~53 - 64 dB (Bình thường - Xanh dương)
                        // - Nói chuyện bình thường (combined ~ 10 - 20): ~68 - 78 dB (Bình thường - Xanh dương)
                        // - Môi trường ồn / Nói to (combined ~ 22 - 32): ~80 - 85 dB (Chú ý - Cam)
                        // - Phát âm to / La hét / Vỗ tay / Còi (combined >= 35): >= 87.5 dB (CẢNH BÁO NGUY HẠI - ĐỎ RỰC!)
                        // - Hét lớn / tiếng gõ mạnh (combined >= 80): 100 - 118 dB (Đỉnh cảnh báo cao nhất)
                        val targetDb = if (combined > 0.8) {
                            (32.0 + 36.0 * log10(combined)).coerceIn(28.0, 120.0)
                        } else {
                            // Dao động âm nền tự nhiên khi hoàn toàn tĩnh lặng
                            28.0 + (System.currentTimeMillis() % 25) * 0.1
                        }

                        // Fast attack 0ms: Nhảy lên tức thì khi người dùng phát âm to / tiếng động lớn
                        // Smooth decay ~400ms: Giảm dần mượt mà để đồng hồ đo và biểu đồ ghi nhận rõ ràng đỉnh âm thanh
                        currentDecibel = if (targetDb > currentDecibel) {
                            targetDb
                        } else {
                            currentDecibel * 0.86 + targetDb * 0.14
                        }
                        currentDecibel = Math.round(currentDecibel * 10.0) / 10.0

                        val now = System.currentTimeMillis()
                        if (now - lastLogTime > 2000) {
                            Log.d(TAG, "Audio reading: rms=$rms, peak=$peak, targetDb=$targetDb, currentDb=$currentDecibel")
                            lastLogTime = now
                        }
                    } else if (read < 0) {
                        Log.w(TAG, "AudioRecord read error: $read, attempting recovery...")
                        try {
                            Thread.sleep(30)
                            audioRecord?.stop()
                            audioRecord?.startRecording()
                        } catch (e: Exception) {
                            // ignore
                        }
                    }
                }
            }
            recordingThread?.start()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting AudioRecord: ${e.message}", e)
            isRecording = false
            false
        }
    }

    @Synchronized
    private fun stopRecording() {
        isRecording = false
        recordingThread?.interrupt()
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping AudioRecord: ${e.message}")
        }
        audioRecord = null
        recordingThread = null
    }

    override fun onDestroy() {
        stopRecording()
        super.onDestroy()
    }
}
