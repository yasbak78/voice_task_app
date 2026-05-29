package com.voicetask.voice_task_app

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "voice_task_app/installer"
    private val SOUND_CHANNEL = "voice_task_app/sound_preview"
    private val HAPTIC_CHANNEL = "voice_task_app/haptic_feedback"
    private val TAG = "MainActivity"
    private var previewPlayer: MediaPlayer? = null
    private var chimePlayer: MediaPlayer? = null
    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Installer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkInstallPermission" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    Log.d(TAG, "checkInstallPermission: $canInstall")
                    result.success(canInstall)
                }
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    Log.d(TAG, "installApk called with path: $filePath")

                    if (filePath == null || filePath.isEmpty()) {
                        Log.e(TAG, "APK file path is null or empty")
                        result.error("INVALID_PATH", "APK file path is null or empty", null)
                        return@setMethodCallHandler
                    }

                    val apkFile = File(filePath)
                    Log.d(TAG, "File exists: ${apkFile.exists()}, canRead: ${apkFile.canRead()}, path: ${apkFile.absolutePath}")

                    if (!apkFile.exists()) {
                        Log.e(TAG, "APK file does not exist: $filePath")
                        result.error("FILE_NOT_FOUND", "APK file does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                apkFile
                            )
                            Log.d(TAG, "FileProvider URI: $uri")
                            uri
                        } else {
                            val uri = Uri.fromFile(apkFile)
                            Log.d(TAG, "File URI: $uri")
                            uri
                        }

                        val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                            data = uri
                            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                            }
                        }

                        Log.d(TAG, "Starting install intent: $installIntent")
                        startActivity(installIntent)
                        Log.d(TAG, "Install intent started successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Install failed with exception: ${e.message}", e)
                        result.error("INSTALL_FAILED", e.message, e.stackTraceToString())
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Sound preview channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playPreview" -> {
                    val soundName = call.argument<String>("sound") ?: ""
                    try {
                        previewPlayer?.stop()
                        previewPlayer?.release()
                        previewPlayer = null

                        val resId = when (soundName) {
                            "gentle_ping" -> R.raw.gentle_ping
                            "classic_bell" -> R.raw.classic_bell
                            "urgent_beep" -> R.raw.urgent_beep
                            "melody" -> R.raw.melody
                            else -> {
                                result.error("UNKNOWN_SOUND", "Sound not found: $soundName", null)
                                return@setMethodCallHandler
                            }
                        }

                        previewPlayer = MediaPlayer.create(this, resId).also { player ->
                            player.start()
                            player.setOnCompletionListener {
                                player.release()
                                previewPlayer = null
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Sound preview failed: ${e.message}")
                        result.error("PLAY_FAILED", e.message, null)
                    }
                }
                "stopPreview" -> {
                    try {
                        previewPlayer?.stop()
                        previewPlayer?.release()
                        previewPlayer = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "playChime" -> {
                    val soundName = call.argument<String>("sound") ?: "completion_chime"
                    try {
                        chimePlayer?.stop()
                        chimePlayer?.release()
                        chimePlayer = null

                        val resId = when (soundName) {
                            "completion_chime" -> R.raw.completion_chime
                            "success_ping" -> R.raw.success_ping
                            "gentle_complete" -> R.raw.gentle_complete
                            else -> {
                                result.error("UNKNOWN_CHIME", "Chime not found: $soundName", null)
                                return@setMethodCallHandler
                            }
                        }

                        chimePlayer = MediaPlayer.create(this, resId).also { player ->
                            player.start()
                            player.setOnCompletionListener {
                                player.release()
                                chimePlayer = null
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Chime play failed: ${e.message}")
                        result.error("CHIME_FAILED", e.message, null)
                    }
                }
                "playSystemNotificationSound" -> {
                    try {
                        val defaultUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        chimePlayer?.stop()
                        chimePlayer?.release()
                        chimePlayer = null

                        chimePlayer = MediaPlayer().apply {
                            setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build()
                            )
                            setDataSource(this@MainActivity, defaultUri)
                            prepare()
                            start()
                            setOnCompletionListener {
                                release()
                                chimePlayer = null
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "System sound failed: ${e.message}")
                        result.error("SYSTEM_SOUND_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Haptic feedback channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTIC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "triggerHaptic" -> {
                    val pattern = call.argument<String>("pattern") ?: "light"
                    try {
                        triggerHapticPattern(pattern)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Haptic failed: ${e.message}")
                        result.error("HAPTIC_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun triggerHapticPattern(pattern: String) {
        if (!vibrator.hasVibrator()) return

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        when (pattern) {
            "light" -> {
                // Single short tap — task added
                val effect = VibrationEffect.createOneShot(15, VibrationEffect.DEFAULT_AMPLITUDE)
                vibrator.vibrate(effect, attrs)
            }
            "medium" -> {
                // Medium tap — snooze or dismiss
                val effect = VibrationEffect.createOneShot(30, VibrationEffect.DEFAULT_AMPLITUDE)
                vibrator.vibrate(effect, attrs)
            }
            "heavy" -> {
                // Strong tap — task completed
                val effect = VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE)
                vibrator.vibrate(effect, attrs)
            }
            "success" -> {
                // Double tap pattern — celebration
                val effect = VibrationEffect.createWaveform(
                    longArrayOf(0, 40, 60, 40, 0), // timing: start, vibrate, pause, vibrate, end
                    intArrayOf(0, VibrationEffect.DEFAULT_AMPLITUDE, 0, VibrationEffect.DEFAULT_AMPLITUDE, 0),
                    -1 // no repeat
                )
                vibrator.vibrate(effect, attrs)
            }
            "triple" -> {
                // Triple tap — multi-action
                val effect = VibrationEffect.createWaveform(
                    longArrayOf(0, 25, 40, 25, 40, 25, 0),
                    intArrayOf(0, VibrationEffect.DEFAULT_AMPLITUDE, 0, VibrationEffect.DEFAULT_AMPLITUDE, 0, VibrationEffect.DEFAULT_AMPLITUDE, 0),
                    -1
                )
                vibrator.vibrate(effect, attrs)
            }
            else -> {
                // Default light tap
                val effect = VibrationEffect.createOneShot(15, VibrationEffect.DEFAULT_AMPLITUDE)
                vibrator.vibrate(effect, attrs)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        previewPlayer?.release()
        previewPlayer = null
        chimePlayer?.release()
        chimePlayer = null
    }
}
