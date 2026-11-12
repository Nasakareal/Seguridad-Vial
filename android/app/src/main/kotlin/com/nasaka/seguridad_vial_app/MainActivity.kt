package com.nasaka.seguridad_vial_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pttEventSink: EventChannel.EventSink? = null
    private var pttReceiverRegistered = false
    private var mediaRecorder: MediaRecorder? = null
    private var recordingFile: File? = null

    private val pttReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val event = when (intent?.action) {
                PTT_DOWN_ACTION -> "down"
                PTT_UP_ACTION -> "up"
                else -> return
            }
            pttEventSink?.success(mapOf("event" to event, "source" to "ruggear"))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seguridad_vial_app/thermal_printer"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBondedPrinters" -> getBondedPrinters(result)
                "printEscPos" -> {
                    val address = call.argument<String>("address")?.trim()
                    val bytes = call.argument<ByteArray>("bytes")
                    if (address.isNullOrEmpty() || bytes == null || bytes.isEmpty()) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Faltan direccion Bluetooth o datos de impresion.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    printEscPos(address, bytes, result)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seguridad_vial_app/ptt_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                pttEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                pttEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seguridad_vial_app/ptt_recorder"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isRugGearDevice())
                "startRecording" -> startPttRecording(result)
                "stopRecording" -> stopPttRecording(result)
                "cancelRecording" -> cancelPttRecording(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (isRugGearDevice()) {
            registerPttReceiver()
        }
    }

    override fun onStop() {
        unregisterPttReceiver()
        super.onStop()
    }

    override fun onDestroy() {
        releaseRecorder(deleteFile = true)
        super.onDestroy()
    }

    private fun registerPttReceiver() {
        if (pttReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(PTT_DOWN_ACTION)
            addAction(PTT_UP_ACTION)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // RugGear emits these PTT intents from outside this app. Android 13+
                // requires dynamically registered receivers to declare this explicitly.
                registerReceiver(pttReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(pttReceiver, filter)
            }
            pttReceiverRegistered = true
        } catch (_: SecurityException) {
            // PTT is optional. An OEM restriction must never prevent the app from
            // starting; the on-screen PTT control remains available.
            pttReceiverRegistered = false
        }
    }

    private fun isRugGearDevice(): Boolean {
        return Build.MANUFACTURER.equals(RUGGEAR, ignoreCase = true) ||
            Build.BRAND.equals(RUGGEAR, ignoreCase = true)
    }

    private fun unregisterPttReceiver() {
        if (!pttReceiverRegistered) return
        try {
            unregisterReceiver(pttReceiver)
        } catch (_: IllegalArgumentException) {
        }
        pttReceiverRegistered = false
    }

    private fun startPttRecording(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Permiso de microfono requerido.", null)
            return
        }
        if (mediaRecorder != null) {
            result.success(recordingFile?.absolutePath)
            return
        }

        try {
            val directory = File(cacheDir, "ptt").apply { mkdirs() }
            val output = File(directory, "ptt_${System.currentTimeMillis()}.m4a")
            @Suppress("DEPRECATION")
            val recorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16000)
                setAudioEncodingBitRate(32000)
                setOutputFile(output.absolutePath)
                prepare()
                start()
            }
            mediaRecorder = recorder
            recordingFile = output
            result.success(output.absolutePath)
        } catch (error: Exception) {
            releaseRecorder(deleteFile = true)
            result.error("RECORDING_FAILED", error.localizedMessage ?: "No se pudo iniciar la grabacion.", null)
        }
    }

    private fun stopPttRecording(result: MethodChannel.Result) {
        val recorder = mediaRecorder
        val output = recordingFile
        if (recorder == null || output == null) {
            result.success(null)
            return
        }

        try {
            recorder.stop()
            recorder.release()
            mediaRecorder = null
            recordingFile = null
            if (output.exists() && output.length() > 0) {
                result.success(output.absolutePath)
            } else {
                output.delete()
                result.success(null)
            }
        } catch (error: RuntimeException) {
            releaseRecorder(deleteFile = true)
            result.error("RECORDING_TOO_SHORT", "Mantén presionado PTT un poco más.", null)
        }
    }

    private fun cancelPttRecording(result: MethodChannel.Result) {
        releaseRecorder(deleteFile = true)
        result.success(true)
    }

    private fun releaseRecorder(deleteFile: Boolean) {
        try {
            mediaRecorder?.stop()
        } catch (_: RuntimeException) {
        }
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
        if (deleteFile) recordingFile?.delete()
        recordingFile = null
    }

    private fun getBondedPrinters(result: MethodChannel.Result) {
        val adapter = defaultBluetoothAdapter()
        if (adapter == null) {
            result.error("NO_ADAPTER", "Bluetooth no esta disponible en este equipo.", null)
            return
        }

        if (!hasBluetoothConnectPermission()) {
            result.error("PERMISSION_DENIED", "Permiso de Bluetooth requerido.", null)
            return
        }

        try {
            if (!adapter.isEnabled) {
                result.error("BLUETOOTH_DISABLED", "Bluetooth esta desactivado.", null)
                return
            }

            val devices = adapter.bondedDevices
                .map { device ->
                    mapOf(
                        "name" to ((device.name ?: "").ifBlank { "Dispositivo Bluetooth" }),
                        "address" to device.address
                    )
                }
                .sortedBy { (it["name"] ?: "").toString().lowercase() }

            result.success(devices)
        } catch (_: SecurityException) {
            result.error("PERMISSION_DENIED", "Permiso de Bluetooth requerido.", null)
        }
    }

    private fun printEscPos(
        address: String,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        val adapter = defaultBluetoothAdapter()
        if (adapter == null) {
            result.error("NO_ADAPTER", "Bluetooth no esta disponible en este equipo.", null)
            return
        }

        if (!hasBluetoothConnectPermission()) {
            result.error("PERMISSION_DENIED", "Permiso de Bluetooth requerido.", null)
            return
        }

        try {
            if (!adapter.isEnabled) {
                result.error("BLUETOOTH_DISABLED", "Bluetooth esta desactivado.", null)
                return
            }
        } catch (_: SecurityException) {
            result.error("PERMISSION_DENIED", "Permiso de Bluetooth requerido.", null)
            return
        }

        Thread {
            try {
                val device = findBondedDevice(adapter, address)
                if (device == null) {
                    postError(result, "DEVICE_NOT_FOUND", "Impresora no emparejada.")
                    return@Thread
                }

                writeToDevice(device, bytes, insecure = true)
                postSuccess(result, true)
            } catch (firstError: IOException) {
                try {
                    val device = findBondedDevice(adapter, address)
                    if (device == null) {
                        postError(result, "DEVICE_NOT_FOUND", "Impresora no emparejada.")
                        return@Thread
                    }
                    writeToDevice(device, bytes, insecure = false)
                    postSuccess(result, true)
                } catch (_: SecurityException) {
                    postError(result, "PERMISSION_DENIED", "Permiso de Bluetooth requerido.")
                } catch (retryError: IOException) {
                    postError(
                        result,
                        "PRINT_FAILED",
                        retryError.localizedMessage
                            ?: firstError.localizedMessage
                            ?: "No se pudo conectar con la impresora."
                    )
                }
            } catch (_: SecurityException) {
                postError(result, "PERMISSION_DENIED", "Permiso de Bluetooth requerido.")
            } catch (error: IllegalArgumentException) {
                postError(
                    result,
                    "DEVICE_NOT_FOUND",
                    error.localizedMessage ?: "Direccion Bluetooth invalida."
                )
            }
        }.start()
    }

    private fun writeToDevice(
        device: BluetoothDevice,
        bytes: ByteArray,
        insecure: Boolean
    ) {
        val socket = createSocket(device, insecure)
        try {
            socket.connect()
            socket.outputStream.use { output ->
                writeBytesInChunks(output, bytes)
            }
        } finally {
            closeQuietly(socket)
        }
    }

    private fun writeBytesInChunks(output: OutputStream, bytes: ByteArray) {
        var offset = 0
        // Estas impresoras termicas reciben por SPP mas rapido de lo que
        // alcanzan a vaciar su buffer. Si cerramos el socket con datos aun
        // pendientes, el ultimo ticket queda truncado.
        val chunkSize = 64
        while (offset < bytes.size) {
            val count = minOf(chunkSize, bytes.size - offset)
            output.write(bytes, offset, count)
            output.flush()
            offset += count
            if (offset < bytes.size) {
                Thread.sleep(60)
            }
        }

        // El avance adicional protege el contenido util del ultimo documento
        // y deja papel suficiente para desprenderlo aun al imprimir una copia.
        output.write(TRAILING_FEED)
        output.flush()

        // OutputStream.flush() solo entrega los bytes a la pila Bluetooth; no
        // garantiza que la impresora ya los haya consumido. Conservamos la
        // conexion abierta para que termine de recibir su ultimo buffer.
        Thread.sleep(2_000)
    }

    private fun createSocket(device: BluetoothDevice, insecure: Boolean): BluetoothSocket {
        return if (insecure) {
            device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
        } else {
            device.createRfcommSocketToServiceRecord(SPP_UUID)
        }
    }

    private fun findBondedDevice(
        adapter: BluetoothAdapter,
        address: String
    ): BluetoothDevice? {
        val normalized = address.trim()
        return try {
            adapter.bondedDevices.firstOrNull {
                it.address.equals(normalized, ignoreCase = true)
            }
        } catch (_: SecurityException) {
            null
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun defaultBluetoothAdapter(): BluetoothAdapter? {
        return BluetoothAdapter.getDefaultAdapter()
    }

    private fun postSuccess(result: MethodChannel.Result, value: Boolean) {
        mainHandler.post { result.success(value) }
    }

    private fun postError(
        result: MethodChannel.Result,
        code: String,
        message: String
    ) {
        mainHandler.post { result.error(code, message, null) }
    }

    private fun closeQuietly(socket: BluetoothSocket) {
        try {
            socket.close()
        } catch (_: IOException) {
        }
    }

    companion object {
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private const val PTT_DOWN_ACTION = "android.intent.action.PTT.down"
        private const val PTT_UP_ACTION = "android.intent.action.PTT.up"
        private const val RUGGEAR = "RugGear"
        private val TRAILING_FEED = byteArrayOf(0x0A, 0x0A, 0x0A, 0x0A)
    }
}
