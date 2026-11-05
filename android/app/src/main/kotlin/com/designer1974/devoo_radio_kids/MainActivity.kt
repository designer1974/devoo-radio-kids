package com.designer1974.devoo_radio_kids

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Activity compatibile con la riproduzione in background (notifica con i controlli)
class MainActivity : AudioServiceActivity() {

    // Il telefono si sta spegnendo: la registrazione si chiude subito (al riavvio si recupera)
    private val shutdown = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            StreamRecorder.shutdown()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val f = IntentFilter(Intent.ACTION_SHUTDOWN)
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(shutdown, f, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(shutdown, f)
            }
        } catch (_: Exception) {}
        try { Scheduler.refreshStandby(this) } catch (_: Exception) {}
    }

    override fun onDestroy() {
        try { unregisterReceiver(shutdown) } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kids/app").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "is64" -> result.success(Build.SUPPORTED_64_BIT_ABIS.isNotEmpty())
                    "openUrl" -> {
                        val ok = try {
                            startActivity(
                                Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            true
                        } catch (_: Exception) {
                            false
                        }
                        result.success(ok)
                    }

                    // ---- aggiornamento dentro l'app ----
                    "installStatus" -> {
                        val p = getSharedPreferences("kids_update", MODE_PRIVATE)
                        result.success(mapOf("status" to p.getInt("status", -100), "msg" to (p.getString("msg", "") ?: "")))
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")!!
                        Thread {
                            val r = try { installApk(path); "ok" } catch (e: Exception) { e.message ?: "errore" }
                            runOnUiThread { result.success(r) }
                        }.start()
                    }

                    // ---- registrazione diretta dello stream ----
                    "streamStart" -> {
                        StreamRecorder.start(
                            call.argument<String>("url")!!,
                            call.argument<String>("dir")!!,
                            call.argument<String>("name")!!,
                            call.argument<String>("dst")!!,
                            call.argument<Int>("bitrate")!!,
                            call.argument<Int>("outCh")!!,
                            call.argument<Boolean>("he")!!,
                        )
                        result.success(null)
                    }
                    "streamStatus" -> result.success(
                        mapOf(
                            "running" to StreamRecorder.running,
                            "busy" to StreamRecorder.busy,
                            "bytes" to StreamRecorder.bytes,
                            "error" to StreamRecorder.error,
                            "startedAt" to StreamRecorder.startedAt,
                            "url" to StreamRecorder.url,
                            "schedId" to ScheduledRecService.activeId,
                            "schedName" to ScheduledRecService.activeName,
                            "schedFlag" to ScheduledRecService.activeFlag,
                            "schedEnd" to ScheduledRecService.activeEnd,
                        )
                    )
                    "streamStop" -> Thread {
                        val p = try { StreamRecorder.stop() } catch (e: Exception) { null }
                        runOnUiThread { result.success(p) }
                    }.start()
                    "recover" -> Thread {
                        val l = try { StreamRecorder.recover(call.argument<String>("dir")!!) } catch (e: Exception) { emptyList() }
                        runOnUiThread { result.success(l) }
                    }.start()
                    "duration" -> {
                        val path = call.argument<String>("path")!!
                        Thread {
                            val d = AudioTools.durationMs(path)
                            runOnUiThread { result.success(d) }
                        }.start()
                    }

                    // ---- registrazioni programmate ----
                    "schedAdd" -> {
                        val m = call.arguments as Map<*, *>
                        val j = org.json.JSONObject()
                        for ((k, v) in m) j.put(k.toString(), v)
                        Scheduler.add(this, j)
                        result.success(null)
                    }
                    "schedList" -> {
                        val a = Scheduler.list(this)
                        result.success((0 until a.length()).map { i ->
                            val o = a.getJSONObject(i)
                            o.keys().asSequence().associateWith { k -> o.get(k) }
                        })
                    }
                    "schedRemove" -> {
                        val id = call.argument<String>("id")!!
                        if (Scheduler.get(this, id)?.optBoolean("running") == true) {
                            try {
                                startService(Intent(this, ScheduledRecService::class.java).setAction(ScheduledRecService.ACTION_STOP))
                            } catch (_: Exception) {}
                        }
                        Scheduler.remove(this, id)
                        result.success(null)
                    }
                    "schedStop" -> {
                        try {
                            startService(Intent(this, ScheduledRecService::class.java).setAction(ScheduledRecService.ACTION_STOP))
                        } catch (_: Exception) {}
                        result.success(null)
                    }
                    "schedExactOk" -> result.success(Scheduler.exactAllowed(this))
                    "schedExactSettings" -> {
                        if (Build.VERSION.SDK_INT >= 31) {
                            try {
                                startActivity(Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName")))
                            } catch (_: Exception) {}
                        }
                        result.success(null)
                    }
                    "batteryOk" -> {
                        val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                        result.success(Build.VERSION.SDK_INT < 23 || pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "batteryAsk" -> {
                        if (Build.VERSION.SDK_INT >= 23) {
                            try {
                                startActivity(Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")))
                            } catch (_: Exception) {
                                try { startActivity(Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) } catch (_: Exception) {}
                            }
                        }
                        result.success(null)
                    }
                    "isHuawei" -> result.success(
                        Build.MANUFACTURER.equals("HUAWEI", true) || Build.MANUFACTURER.equals("HONOR", true)
                    )
                    "openAutostart" -> {
                        // pagina "Avvio app" di Huawei/Honor; se non c'è, le impostazioni dell'app
                        val tries = listOf(
                            android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                            android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
                            android.content.ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                        )
                        var ok = false
                        for (c in tries) {
                            try { startActivity(Intent().setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); ok = true; break } catch (_: Exception) {}
                        }
                        if (!ok) {
                            try {
                                startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")))
                            } catch (_: Exception) {}
                        }
                        result.success(ok)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("REC", e.message ?: "Errore", null)
            }
        }
    }

    /**
     * Aggiornamento: passa l'APK scaricato all'installatore di Android (PackageInstaller).
     * Android poi mostra la conferma "Installa" e l'app nuova prende il posto della vecchia.
     */
    private fun installApk(path: String) {
        val f = java.io.File(path)
        getSharedPreferences("kids_update", MODE_PRIVATE).edit().putInt("status", -100).putString("msg", "").commit()
        val pi = packageManager.packageInstaller
        val params = android.content.pm.PackageInstaller.SessionParams(
            android.content.pm.PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        val id = pi.createSession(params)
        pi.openSession(id).use { s ->
            f.inputStream().use { input ->
                s.openWrite("update.apk", 0, f.length()).use { out ->
                    input.copyTo(out, 256 * 1024)
                    s.fsync(out)
                }
            }
            val flags = android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 31) android.app.PendingIntent.FLAG_MUTABLE else 0)
            val sender = android.app.PendingIntent.getBroadcast(
                this, id, Intent(this, InstallReceiver::class.java), flags
            ).intentSender
            s.commit(sender)
        }
    }
}
