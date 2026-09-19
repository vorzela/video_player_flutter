package com.vorzela.video_player_flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

@UnstableApi
class VideoPlayerFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var context: Context
  private lateinit var textures: TextureRegistry

  private var eventSink: EventChannel.EventSink? = null
  private val players = ConcurrentHashMap<Int, PlayerSession>()
  private val nextId = AtomicInteger(1)
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    textures = binding.textureRegistry
    channel = MethodChannel(binding.binaryMessenger, "com.vorzela.video_player_flutter/player")
    channel.setMethodCallHandler(this)
    eventChannel = EventChannel(binding.binaryMessenger, "com.vorzela.video_player_flutter/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    players.values.forEach { it.release() }
    players.clear()
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "create" -> {
        val id = nextId.getAndIncrement()
        val entry = textures.createSurfaceTexture()
        val session = PlayerSession(id, entry, context, mainHandler) { event ->
          mainHandler.post { eventSink?.success(event) }
        }
        players[id] = session
        result.success(id)
      }
      "load" -> {
        val id = call.argument<Int>("playerId") ?: return result.error("bad_args", "playerId", null)
        val uri = call.argument<String>("uri") ?: return result.error("bad_args", "uri", null)
        val session = players[id] ?: return result.error("missing", "player", null)
        val scheme = android.net.Uri.parse(uri).scheme?.lowercase()
        // HTTPS only: blocks file:// / content:// and cleartext http://.
        if (scheme != "https") {
          return result.error(
            "insecure_uri",
            "Only https:// URIs are allowed, got scheme=$scheme",
            null,
          )
        }
        session.load(
          uri = uri,
          autoPlay = call.argument<Boolean>("autoPlay") ?: false,
          fastStart = call.argument<Boolean>("fastStart") ?: true,
          capToPlayerSize = call.argument<Boolean>("capToPlayerSize") ?: true,
          viewWidth = call.argument<Int>("viewWidth"),
          viewHeight = call.argument<Int>("viewHeight"),
        )
        result.success(null)
      }
      "play" -> {
        players[call.argId()]?.play()
        result.success(null)
      }
      "pause" -> {
        players[call.argId()]?.pause()
        result.success(null)
      }
      "seek" -> {
        val ms = call.argument<Int>("positionMs") ?: 0
        players[call.argId()]?.seek(ms.toLong())
        result.success(null)
      }
      "setVolume" -> {
        val v = (call.argument<Double>("volume") ?: 1.0).toFloat()
        players[call.argId()]?.setVolume(v)
        result.success(null)
      }
      "setQuality" -> {
        val q = call.argument<String>("quality") ?: "auto"
        players[call.argId()]?.setQuality(q)
        result.success(null)
      }
      "getLevels" -> {
        result.success(players[call.argId()]?.levels() ?: emptyList<Map<String, Any>>())
      }
      "dispose" -> {
        val id = call.argId()
        players.remove(id)?.release()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun MethodCall.argId(): Int = argument<Int>("playerId") ?: -1
}

@UnstableApi
private class PlayerSession(
  private val id: Int,
  private val textureEntry: TextureRegistry.SurfaceTextureEntry,
  context: Context,
  private val handler: Handler,
  private val emit: (Map<String, Any?>) -> Unit,
) : Player.Listener {
  private val trackSelector = DefaultTrackSelector(context)
  // Tight buffers: lower RAM than ExoPlayer defaults (~50s).
  private val loadControl = DefaultLoadControl.Builder()
    .setBufferDurationsMs(
      /* minBufferMs */ 2_000,
      /* maxBufferMs */ 10_000,
      /* bufferForPlaybackMs */ 500,
      /* bufferForPlaybackAfterRebufferMs */ 1_000,
    )
    .build()

  private val player: ExoPlayer = ExoPlayer.Builder(context)
    .setTrackSelector(trackSelector)
    .setLoadControl(loadControl)
    .build()

  private var surface: Surface = Surface(textureEntry.surfaceTexture())
  private var lastPositionEmit = 0L
  private var fastStart = true
  private var released = false
  private val tickRunnable = object : Runnable {
    override fun run() {
      if (released) return
      if (player.playbackState != Player.STATE_IDLE && player.playbackState != Player.STATE_ENDED) {
        val now = System.currentTimeMillis()
        if (now - lastPositionEmit >= 250) {
          lastPositionEmit = now
          val buffered = player.bufferedPosition.coerceAtLeast(0)
          emit(
            mapOf(
              "type" to "position",
              "playerId" to id,
              "positionMs" to player.currentPosition,
              "bufferedMs" to buffered,
            ),
          )
        }
      }
      handler.postDelayed(this, 250)
    }
  }

  init {
    player.setVideoSurface(surface)
    player.addListener(this)
    handler.post(tickRunnable)
  }

  fun load(
    uri: String,
    autoPlay: Boolean,
    fastStart: Boolean,
    capToPlayerSize: Boolean,
    viewWidth: Int?,
    viewHeight: Int?,
  ) {
    this.fastStart = fastStart
    if (capToPlayerSize && viewWidth != null && viewHeight != null && viewWidth > 0 && viewHeight > 0) {
      trackSelector.parameters = trackSelector.buildUponParameters()
        .setMaxVideoSize(viewWidth, viewHeight)
        .build()
    }
    // liveConfiguration is a no-op for VOD; for live HLS it tracks ~3s behind
    // the live edge (VOD-tuned tight buffers alone stall/drift on live).
    val mediaItem = MediaItem.Builder()
      .setUri(uri)
      .setLiveConfiguration(
        MediaItem.LiveConfiguration.Builder()
          .setTargetOffsetMs(3_000)
          .setMinPlaybackSpeed(0.97f)
          .setMaxPlaybackSpeed(1.03f)
          .build(),
      )
      .build()
    player.setMediaItem(mediaItem)
    player.prepare()
    player.playWhenReady = autoPlay
  }

  fun play() {
    player.playWhenReady = true
    player.play()
  }

  fun pause() {
    player.pause()
  }

  fun seek(ms: Long) {
    player.seekTo(ms)
  }

  fun setVolume(v: Float) {
    player.volume = v.coerceIn(0f, 1f)
  }

  fun setQuality(quality: String) {
    val params = trackSelector.buildUponParameters()
    if (quality == "auto") {
      trackSelector.parameters = params.clearOverridesOfType(C.TRACK_TYPE_VIDEO).build()
      return
    }
    val height = quality.removeSuffix("p").toIntOrNull() ?: return
    val groups = player.currentTracks.groups
    for (group in groups) {
      if (group.type != C.TRACK_TYPE_VIDEO) continue
      for (i in 0 until group.length) {
        val format = group.getTrackFormat(i)
        if (format.height == height) {
          trackSelector.parameters = params
            .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, listOf(i)))
            .build()
          return
        }
      }
    }
  }

  fun levels(): List<Map<String, Any>> {
    val out = mutableListOf<Map<String, Any>>()
    val groups = player.currentTracks.groups
    var index = 0
    for (group in groups) {
      if (group.type != C.TRACK_TYPE_VIDEO) continue
      for (i in 0 until group.length) {
        val format = group.getTrackFormat(i)
        if (format.height <= 0) continue
        out.add(
          mapOf(
            "index" to index,
            "height" to format.height,
            "bitrate" to format.bitrate.coerceAtLeast(0),
            "label" to "${format.height}p",
          ),
        )
        index += 1
      }
    }
    return out.sortedBy { it["height"] as Int }
  }

  override fun onPlaybackStateChanged(playbackState: Int) {
    when (playbackState) {
      Player.STATE_BUFFERING -> emit(mapOf("type" to "buffering", "playerId" to id, "isBuffering" to true))
      Player.STATE_READY -> {
        emit(mapOf("type" to "buffering", "playerId" to id, "isBuffering" to false))
        if (fastStart) {
          // Prefer lowest rung first; ABR climbs afterward.
          val sorted = levels()
          if (sorted.isNotEmpty()) {
            setQuality(sorted.first()["label"] as String)
            // Return to auto after first frame readiness so ABR can climb.
            handler.postDelayed({ setQuality("auto") }, 1_500)
          }
        }
        emitReady()
      }
      Player.STATE_ENDED -> emit(mapOf("type" to "completed", "playerId" to id))
    }
  }

  override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
    if (videoSize.width <= 0 || videoSize.height <= 0) return
    // Dimensions often arrive after STATE_READY — re-emit ready so Dart
    // can pick up the real aspect ratio without a hardcoded 16:9.
    emitReady()
  }

  private fun emitReady() {
    val size = player.videoSize
    emit(
      mapOf(
        "type" to "ready",
        "playerId" to id,
        "textureId" to textureEntry.id(),
        "durationMs" to player.duration.coerceAtLeast(0),
        "levels" to levels(),
        "videoWidth" to size.width,
        "videoHeight" to size.height,
      ),
    )
  }

  override fun onPlayerError(error: PlaybackException) {
    emit(mapOf("type" to "error", "playerId" to id, "message" to (error.message ?: "playback error")))
  }

  fun release() {
    released = true
    handler.removeCallbacks(tickRunnable)
    player.removeListener(this)
    // Detach surface before release — avoids IllegalStateException under
    // rapid create/dispose churn (fast-scrolling feeds).
    player.clearVideoSurface(surface)
    player.release()
    surface.release()
    textureEntry.release()
  }
}
