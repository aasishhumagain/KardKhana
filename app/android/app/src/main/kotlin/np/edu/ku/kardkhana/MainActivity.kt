package np.edu.ku.kardkhana

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var soundPool: SoundPool? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val pool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
        soundPool = pool

        val ready = mutableSetOf<Int>()
        pool.setOnLoadCompleteListener { _, sample, status ->
            if (status == 0) ready.add(sample)
        }
        val shuffle = pool.load(this, R.raw.card_shuffle, 1)
        val pickUp = pool.load(this, R.raw.card_pickup, 1)
        val drop = pool.load(this, R.raw.card_drop, 1)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kardkhana/card_sounds")
        channel?.setMethodCallHandler { call, result ->
            val cue = if (call.method == "play") call.arguments as? String else null
            val sound = when (cue) {
                "shuffle" -> shuffle to 0.85f
                "deal" -> pickUp to 0.30f
                "pickUp" -> pickUp to 0.72f
                "drop" -> drop to 0.65f
                else -> null
            }
            if (sound == null) {
                result.notImplemented()
            } else {
                val (sample, volume) = sound
                if (sample in ready) pool.play(sample, volume, volume, 1, 0, 1f)
                result.success(null)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        soundPool?.release()
        soundPool = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
