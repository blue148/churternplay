package com.churternplay.churternPlay

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val textRecognizerDelegate = lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }
    private val textRecognizer by textRecognizerDelegate

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // On-device OCR for the box-title scanner, backed by ML Kit.
        // Returns {imageWidth, imageHeight, lines: [{text, left, top, width, height}]}
        // with boxes normalised to 0–1 from the top-left of the upright image —
        // the same shape the iOS (Apple Vision) implementation returns.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "churternplay/text_recognition")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "Missing image path", null)
                    return@setMethodCallHandler
                }
                recognize(path, result)
            }
    }

    private fun recognize(path: String, result: MethodChannel.Result) {
        val image = try {
            // fromFilePath applies EXIF rotation, so boxes are relative to the
            // upright image and width/height below are post-rotation.
            InputImage.fromFilePath(this, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            result.error("recognition_failed", e.message, null)
            return
        }

        val (width, height) = if (image.rotationDegrees % 180 == 0) {
            image.width to image.height
        } else {
            image.height to image.width
        }
        val w = width.toDouble().coerceAtLeast(1.0)
        val h = height.toDouble().coerceAtLeast(1.0)

        textRecognizer.process(image)
            .addOnSuccessListener { text ->
                val lines = text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                    val box = line.boundingBox ?: return@mapNotNull null
                    mapOf(
                        "text" to line.text,
                        "left" to box.left / w,
                        "top" to box.top / h,
                        "width" to box.width() / w,
                        "height" to box.height() / h,
                    )
                }
                result.success(
                    mapOf("imageWidth" to width, "imageHeight" to height, "lines" to lines)
                )
            }
            .addOnFailureListener { e ->
                result.error("recognition_failed", e.message, null)
            }
    }

    override fun onDestroy() {
        if (textRecognizerDelegate.isInitialized()) textRecognizer.close()
        super.onDestroy()
    }
}
