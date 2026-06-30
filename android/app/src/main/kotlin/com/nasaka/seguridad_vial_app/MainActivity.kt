package com.nasaka.seguridad_vial_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())

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

                try {
                    adapter.cancelDiscovery()
                } catch (_: SecurityException) {
                    // No estamos escaneando; cancelar discovery solo mejora la conexion si esta permitido.
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
        val chunkSize = 128
        while (offset < bytes.size) {
            val count = minOf(chunkSize, bytes.size - offset)
            output.write(bytes, offset, count)
            output.flush()
            offset += count
            if (offset < bytes.size) {
                Thread.sleep(25)
            }
        }
        output.flush()
        Thread.sleep(400)
    }

    private fun createSocket(device: BluetoothDevice, insecure: Boolean): BluetoothSocket {
        return if (insecure && Build.VERSION.SDK_INT >= Build.VERSION_CODES.GINGERBREAD_MR1) {
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
        return adapter.bondedDevices.firstOrNull {
            it.address.equals(normalized, ignoreCase = true)
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
    }
}
