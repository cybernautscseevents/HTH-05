package `in`.saathi.care.saathi_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "saathi/discharge_document"
    private val pickDocumentRequest = 8194
    private val captureDocumentRequest = 8195
    private val cameraPermissionRequest = 8196
    private var pendingResult: MethodChannel.Result? = null
    private var captureFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickDocument" && call.method != "captureDocument") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("document_busy", "A document action is already open", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                if (call.method == "captureDocument") {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                        PackageManager.PERMISSION_GRANTED) {
                        launchCamera()
                    } else {
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.CAMERA), cameraPermissionRequest
                        )
                    }
                } else {
                    launchPicker()
                }
            }
    }

    private fun launchPicker() {
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "image/jpeg", "image/png"))
            }
            startActivityForResult(intent, pickDocumentRequest)
        } catch (error: Exception) {
            pendingResult?.error("picker_unavailable", "Unable to open the document picker", null)
            pendingResult = null
        }
    }

    private fun launchCamera() {
        try {
            val file = File.createTempFile("saathi-report-", ".jpg", cacheDir)
            captureFile = file
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, uri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(intent, captureDocumentRequest)
        } catch (error: Exception) {
            captureFile?.delete()
            captureFile = null
            pendingResult?.error("camera_unavailable", "Unable to open the camera on this device", null)
            pendingResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != cameraPermissionRequest) return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            launchCamera()
        } else {
            pendingResult?.error("camera_permission", "Camera permission was denied", null)
            pendingResult = null
        }
    }

    @Deprecated("Deprecated in Android API; FlutterActivity callback remains compatible")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickDocumentRequest && requestCode != captureDocumentRequest) return
        val result = pendingResult ?: return
        pendingResult = null
        if (requestCode == captureDocumentRequest) {
            val file = captureFile
            captureFile = null
            if (resultCode != RESULT_OK) {
                file?.delete()
                result.success(null)
                return
            }
            try {
                if (file == null || !file.exists() || file.length() == 0L) {
                    throw IllegalStateException("The camera did not save an image")
                }
                result.success(mapOf(
                    "name" to "captured-report-${System.currentTimeMillis()}.jpg",
                    "bytes" to file.readBytes()
                ))
            } catch (error: Exception) {
                result.error("capture_failed", "Unable to read the captured image", null)
            } finally {
                file?.delete()
            }
            return
        }
        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        try {
            val uri: Uri = data.data!!
            val name = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && column >= 0) cursor.getString(column) else null
            } ?: "discharge-document"
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalStateException("Unable to open selected document")
            result.success(mapOf("name" to name, "bytes" to bytes))
        } catch (error: Exception) {
            result.error("read_failed", "Unable to read the selected document", null)
        }
    }
}
