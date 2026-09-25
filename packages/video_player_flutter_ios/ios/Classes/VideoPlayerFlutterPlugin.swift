import AVFoundation
import Flutter
import UIKit

public class VideoPlayerFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var channel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  /// Single sink: Flutter EventChannel allows only one active listener.
  /// Dart shares one `receiveBroadcastStream` and filters by `playerId`.
  private var eventSink: FlutterEventSink?
  private var registrar: FlutterPluginRegistrar?
  private var players: [Int: PlayerSession] = [:]
  private var nextId = 1

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VideoPlayerFlutterPlugin()
    instance.registrar = registrar
    let channel = FlutterMethodChannel(
      name: "com.vorzela.video_player_flutter/player",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler(instance.handle)
    instance.channel = channel

    let events = FlutterEventChannel(
      name: "com.vorzela.video_player_flutter/events",
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)
    instance.eventChannel = events
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "create":
      guard let registrar = registrar else {
        result(FlutterError(code: "no_registrar", message: nil, details: nil))
        return
      }
      let id = nextId
      nextId += 1
      let session = PlayerSession(id: id, registrar: registrar) { [weak self] event in
        self?.eventSink?(event)
      }
      players[id] = session
      result(id)
    case "load":
      guard let id = args?["playerId"] as? Int,
        let uri = args?["uri"] as? String,
        let session = players[id]
      else {
        result(FlutterError(code: "bad_args", message: nil, details: nil))
        return
      }
      // HTTPS only — blocks file:// and cleartext http://.
      guard let scheme = URL(string: uri)?.scheme?.lowercased(), scheme == "https" else {
        result(
          FlutterError(
            code: "insecure_uri", message: "Only https:// URIs are allowed", details: nil))
        return
      }
      session.load(
        uri: uri,
        autoPlay: args?["autoPlay"] as? Bool ?? false,
        fastStart: args?["fastStart"] as? Bool ?? true,
        capToPlayerSize: args?["capToPlayerSize"] as? Bool ?? true,
        viewWidth: args?["viewWidth"] as? Int,
        viewHeight: args?["viewHeight"] as? Int
      )
      result(nil)
    case "play":
      players[args?["playerId"] as? Int ?? -1]?.play()
      result(nil)
    case "pause":
      players[args?["playerId"] as? Int ?? -1]?.pause()
      result(nil)
    case "seek":
      let ms = args?["positionMs"] as? Int ?? 0
      players[args?["playerId"] as? Int ?? -1]?.seek(ms: ms)
      result(nil)
    case "setVolume":
      let v = args?["volume"] as? Double ?? 1.0
      players[args?["playerId"] as? Int ?? -1]?.setVolume(Float(v))
      result(nil)
    case "setQuality":
      let q = args?["quality"] as? String ?? "auto"
      players[args?["playerId"] as? Int ?? -1]?.setQuality(q)
      result(nil)
    case "getLevels":
      result(players[args?["playerId"] as? Int ?? -1]?.levels() ?? [])
    case "dispose":
      let id = args?["playerId"] as? Int ?? -1
      players.removeValue(forKey: id)?.release()
      result(nil)
    case "isPictureInPictureSupported":
      // Texture-backed AVPlayer has no system PiP without AVPlayerLayer —
      // opt-in Android PiP covers "play over other apps"; iOS returns false.
      result(false)
    case "enterPictureInPicture":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private final class PlayerSession: NSObject {
  private let id: Int
  private let emit: ([String: Any]) -> Void
  private let texture: FlutterTextureRegistry
  private var textureId: Int64 = -1
  private var output: FlutterTexture?
  private var player: AVPlayer?
  private var item: AVPlayerItem?
  private var videoOutput: AVPlayerItemVideoOutput?
  private var displayLink: CADisplayLink?
  private var lastPositionEmit: CFTimeInterval = 0
  private var fastStart = true
  private var hasGoodFrame = false
  private var didEmitFirstFrame = false
  // Written on CADisplayLink (main), read on Flutter raster thread.
  private let pixelBufferLock = NSLock()
  private var _pixelBuffer: CVPixelBuffer?
  private var pixelBuffer: CVPixelBuffer? {
    get {
      pixelBufferLock.lock()
      defer { pixelBufferLock.unlock() }
      return _pixelBuffer
    }
    set {
      pixelBufferLock.lock()
      _pixelBuffer = newValue
      pixelBufferLock.unlock()
    }
  }

  init(id: Int, registrar: FlutterPluginRegistrar, emit: @escaping ([String: Any]) -> Void) {
    self.id = id
    self.emit = emit
    self.texture = registrar.textures()
    super.init()
    let tex = TextureProxy { [weak self] in self?.pixelBuffer }
    textureId = texture.register(tex)
    output = tex
  }

  func load(
    uri: String, autoPlay: Bool, fastStart: Bool, capToPlayerSize: Bool, viewWidth: Int?,
    viewHeight: Int?
  ) {
    self.fastStart = fastStart
    self.hasGoodFrame = false
    self.didEmitFirstFrame = false
    self.pixelBuffer = nil
    guard let url = URL(string: uri) else {
      emit(["type": "error", "playerId": id, "message": "bad uri"])
      return
    }
    let item = AVPlayerItem(url: url)
    if capToPlayerSize, let h = viewHeight, h > 0 {
      item.preferredPeakBitRate = Double(max(h, 240) * 4_000)
    }
    // No-op for VOD; for live HLS keeps playback ~3s behind the live edge.
    if #available(iOS 14.0, *) {
      item.configuredTimeOffsetFromLive = CMTime(seconds: 3, preferredTimescale: 1)
    }
    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
    item.add(videoOutput)
    self.videoOutput = videoOutput
    self.item = item

    let player = AVPlayer(playerItem: item)
    self.player = player

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onEnd),
      name: .AVPlayerItemDidPlayToEndTime,
      object: item
    )

    item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
    item.addObserver(self, forKeyPath: "presentationSize", options: [.new], context: nil)

    displayLink = CADisplayLink(target: self, selector: #selector(onTick))
    displayLink?.preferredFramesPerSecond = 30
    displayLink?.add(to: .main, forMode: .common)
    // Start paused unless autoplaying: otherwise the link ticks at 30Hz
    // (copying pixel buffers + position IPC) while nothing is playing.
    displayLink?.isPaused = !autoPlay

    if autoPlay { player.play() }
  }

  override func observeValue(
    forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard let item = item else { return }
    if keyPath == "presentationSize" {
      if item.presentationSize.width > 0 && item.presentationSize.height > 0 {
        emitReady(item: item)
      }
      return
    }
    guard keyPath == "status" else { return }
    switch item.status {
    case .readyToPlay:
      if fastStart {
        item.preferredPeakBitRate = 800_000
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          item.preferredPeakBitRate = 0
        }
      }
      emitReady(item: item)
    case .failed:
      emit([
        "type": "error", "playerId": id, "message": item.error?.localizedDescription ?? "failed",
      ])
    default:
      break
    }
  }

  private func emitReady(item: AVPlayerItem) {
    let durationMs = Int((item.duration.seconds.isFinite ? item.duration.seconds : 0) * 1000)
    let size = item.presentationSize
    emit([
      "type": "ready",
      "playerId": id,
      "textureId": textureId,
      "durationMs": durationMs,
      "levels": levels(),
      "videoWidth": Int(size.width),
      "videoHeight": Int(size.height),
    ])
    // Push one frame while paused so posters/previews can swap to video
    // without leaving the display link running at 30Hz. Blank frames are
    // rejected so Dart keeps the poster until a real frame arrives.
    _ = pushFrameIfAvailable(rejectBlank: true)
    emitPosition()
  }

  @objc private func onTick() {
    _ = pushFrameIfAvailable(rejectBlank: !hasGoodFrame)
    let now = CACurrentMediaTime()
    if now - lastPositionEmit >= 0.25 {
      lastPositionEmit = now
      emitPosition()
    }
  }

  @discardableResult
  private func pushFrameIfAvailable(rejectBlank: Bool) -> Bool {
    guard let videoOutput = videoOutput else { return false }
    let t = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
    guard videoOutput.hasNewPixelBuffer(forItemTime: t),
      let buffer = videoOutput.copyPixelBuffer(forItemTime: t, itemTimeForDisplay: nil)
    else { return false }
    if rejectBlank && isNearBlackOrWhite(buffer) {
      return false
    }
    pixelBuffer = buffer
    hasGoodFrame = true
    texture.textureFrameAvailable(textureId)
    if !didEmitFirstFrame {
      didEmitFirstFrame = true
      emit(["type": "firstFrame", "playerId": id])
    }
    return true
  }

  /// Samples a coarse grid; near-solid black/white clears are common before
  /// the decoder produces a real frame and look like a flash over the poster.
  private func isNearBlackOrWhite(_ buffer: CVPixelBuffer) -> Bool {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return true }
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    guard width > 1, height > 1 else { return true }

    let steps = 8
    var sum = 0.0
    var minL = 1.0
    var maxL = 0.0
    var count = 0
    for gy in 0..<steps {
      for gx in 0..<steps {
        let x = gx * (width - 1) / (steps - 1)
        let y = gy * (height - 1) / (steps - 1)
        let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        let b = Double(row[x * 4])
        let g = Double(row[x * 4 + 1])
        let r = Double(row[x * 4 + 2])
        let l = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        sum += l
        minL = min(minL, l)
        maxL = max(maxL, l)
        count += 1
      }
    }
    let avg = sum / Double(count)
    let contrast = maxL - minL
    if avg < 0.04 && contrast < 0.08 { return true }
    if avg > 0.96 && contrast < 0.08 { return true }
    return false
  }

  private func emitPosition() {
    guard let player = player else { return }
    let pos = Int((player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0) * 1000)
    emit([
      "type": "position",
      "playerId": id,
      "positionMs": pos,
      "bufferedMs": pos,
    ])
  }

  @objc private func onEnd() {
    // AVPlayer stops advancing at end-of-item; stop the display link too.
    displayLink?.isPaused = true
    emit(["type": "completed", "playerId": id])
  }

  func play() {
    player?.play()
    displayLink?.isPaused = false
  }

  func pause() {
    player?.pause()
    displayLink?.isPaused = true
  }

  func seek(ms: Int) {
    let t = CMTime(value: CMTimeValue(ms), timescale: 1000)
    player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
      guard finished, let self = self else { return }
      // Reject blank seek frames so we keep the last good frame / poster.
      _ = self.pushFrameIfAvailable(rejectBlank: true)
      self.emitPosition()
    }
  }
  func setVolume(_ v: Float) { player?.volume = max(0, min(1, v)) }
  func setQuality(_ quality: String) {
    guard let item = item else { return }
    if quality == "auto" {
      item.preferredPeakBitRate = 0
      return
    }
    if let h = Int(quality.replacingOccurrences(of: "p", with: "")) {
      item.preferredPeakBitRate = Double(h * 4_000)
    }
  }

  func levels() -> [[String: Any]] {
    // AVPlayer does not expose HLS rungs as cleanly as ExoPlayer; return empty
    // and rely on preferredPeakBitRate for memory caps.
    return []
  }

  func release() {
    displayLink?.invalidate()
    displayLink = nil
    if let item = item {
      item.removeObserver(self, forKeyPath: "status")
      item.removeObserver(self, forKeyPath: "presentationSize")
      NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
    }
    player?.pause()
    player = nil
    item = nil
    videoOutput = nil
    if textureId >= 0 {
      texture.unregisterTexture(textureId)
    }
  }
}

private final class TextureProxy: NSObject, FlutterTexture {
  private let provider: () -> CVPixelBuffer?
  init(_ provider: @escaping () -> CVPixelBuffer?) { self.provider = provider }
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let buf = provider() else { return nil }
    return Unmanaged.passRetained(buf)
  }
}
