import Foundation
import MediaPlayer

public final class CrossfadeQueuedAudioPlayer {

    // MARK: - Players

    private let primary: QueuedAudioPlayer
    private let secondary: QueuedAudioPlayer

    private var active: QueuedAudioPlayer
    private var inactive: QueuedAudioPlayer

    // MARK: - Events

    public let event = AudioPlayer.EventHolder()

    // MARK: - Crossfade State

    private let crossfadeDuration: TimeInterval = 3.0
    private var hasPreparedNextTrack: Bool = false
    private var crossfadeTimer: Timer?

    // MARK: - Init

    public init(
        nowPlayingInfoController: NowPlayingInfoControllerProtocol = NowPlayingInfoController(),
        remoteCommandController: RemoteCommandController = RemoteCommandController()
    ) {
        self.primary = QueuedAudioPlayer(
            nowPlayingInfoController: nowPlayingInfoController,
            remoteCommandController: remoteCommandController
        )

        self.secondary = QueuedAudioPlayer(
            nowPlayingInfoController: NowPlayingInfoController(),
            remoteCommandController: RemoteCommandController()
        )

        self.active = primary
        self.inactive = secondary

        bindEvents(from: active)
    }

    // MARK: - Event Bridging (active only)

    private func bindEvents(from player: QueuedAudioPlayer) {
        player.event.stateChange.addListener(self) { [weak self] state in
            self?.event.stateChange.emit(data: state)
        }

        player.event.playWhenReadyChange.addListener(self) { [weak self] value in
            self?.event.playWhenReadyChange.emit(data: value)
        }

        player.event.playbackEnd.addListener(self) { [weak self] reason in
            self?.event.playbackEnd.emit(data: reason)
        }

        player.event.secondElapse.addListener(self) { [weak self] seconds in
            guard let self else { return }
            self.event.secondElapse.emit(data: seconds)
            self.checkForUpcomingCrossfade()
        }

        player.event.fail.addListener(self) { [weak self] error in
            self?.event.fail.emit(data: error)
        }

        player.event.seek.addListener(self) { [weak self] data in
            self?.event.seek.emit(data: data)
        }

        player.event.updateDuration.addListener(self) { [weak self] duration in
            self?.event.updateDuration.emit(data: duration)
        }

        player.event.receiveCommonMetadata.addListener(self) { [weak self] metadata in
            self?.event.receiveCommonMetadata.emit(data: metadata)
        }

        player.event.receiveTimedMetadata.addListener(self) { [weak self] metadata in
            self?.event.receiveTimedMetadata.emit(data: metadata)
        }

        player.event.receiveChapterMetadata.addListener(self) { [weak self] metadata in
            self?.event.receiveChapterMetadata.emit(data: metadata)
        }

        player.event.didRecreateAVPlayer.addListener(self) { [weak self] _ in
            self?.event.didRecreateAVPlayer.emit(data: ())
        }

        player.event.currentItem.addListener(self) { [weak self] data in
            self?.hasPreparedNextTrack = false
            self?.event.currentItem.emit(data: data)
        }
    }

    // MARK: - Step 3: End-of-track detection

    private func checkForUpcomingCrossfade() {
        guard !hasPreparedNextTrack else { return }

        let duration = active.duration
        let currentTime = active.currentTime
        guard duration > 0 else { return }

        let remaining = duration - currentTime
        guard remaining <= crossfadeDuration else { return }

        if active.repeatMode == .track { return }
        guard let nextItem = active.nextItems.first else { return }

        hasPreparedNextTrack = true
        prepareNextTrackForCrossfade(nextItem)
    }

    // MARK: - Step 4: Prime inactive player

    private func prepareNextTrackForCrossfade(_ item: AudioItem) {
        inactive.clear()
        inactive.load(item: item, playWhenReady: false)
        inactive.volume = 0.0
        inactive.pause()

        startCrossfade()
    }

    // MARK: - Step 5: Crossfade

    private func startCrossfade() {
        crossfadeTimer?.invalidate()

        inactive.play()

        let steps = 30
        let interval = crossfadeDuration / Double(steps)
        var step = 0

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            step += 1
            let progress = min(1.0, Double(step) / Double(steps))

            self.active.volume = Float(1.0 - progress)
            self.inactive.volume = Float(progress)

            if progress >= 1.0 {
                timer.invalidate()
                self.finishCrossfade()
            }
        }
    }

    private func finishCrossfade() {
        active.stop()
        active.clear()

        swap(&active, &inactive)

        active.volume = 1.0
        inactive.volume = 0.0
        hasPreparedNextTrack = false

        bindEvents(from: active)
    }

    // MARK: - Forwarded Core Properties

    public var automaticallyUpdateNowPlayingInfo: Bool {
        get { active.automaticallyUpdateNowPlayingInfo }
        set { active.automaticallyUpdateNowPlayingInfo = newValue }
    }

    public var audioTimePitchAlgorithm: AVAudioTimePitchAlgorithm {
        get { active.audioTimePitchAlgorithm }
        set { active.audioTimePitchAlgorithm = newValue }
    }

    public var remoteCommands: [RemoteCommand] {
        get { active.remoteCommands }
        set { active.remoteCommands = newValue }
    }

    public var playbackError: AudioPlayerError.PlaybackError? {
        active.playbackError
    }

    public var currentTime: Double {
        active.currentTime
    }

    public var duration: Double {
        active.duration
    }

    public var bufferedPosition: Double {
        active.bufferedPosition
    }

    public var playerState: AudioPlayerState {
        active.playerState
    }

    public var playWhenReady: Bool {
        get { active.playWhenReady }
        set { active.playWhenReady = newValue }
    }

    public var bufferDuration: TimeInterval {
        get { active.bufferDuration }
        set { active.bufferDuration = newValue }
    }

    public var timeEventFrequency: TimeEventFrequency {
        get { active.timeEventFrequency }
        set { active.timeEventFrequency = newValue }
    }

    public var volume: Float {
        get { active.volume }
        set { active.volume = newValue }
    }

    public var isMuted: Bool {
        get { active.isMuted }
        set { active.isMuted = newValue }
    }

    public var rate: Float {
        get { active.rate }
        set { active.rate = newValue }
    }

    // MARK: - Queue Surface

    public var repeatMode: RepeatMode {
        get { active.repeatMode }
        set { active.repeatMode = newValue }
    }

    public var currentItem: AudioItem? {
        active.currentItem
    }

    public var currentIndex: Int {
        active.currentIndex
    }

    public var items: [AudioItem] {
        active.items
    }

    public var previousItems: [AudioItem] {
        active.previousItems
    }

    public var nextItems: [AudioItem] {
        active.nextItems
    }

    // MARK: - Player Actions

    public func load(item: AudioItem, playWhenReady: Bool? = nil) {
        active.load(item: item, playWhenReady: playWhenReady)
    }

    public func play() {
        active.play()
    }

    public func pause() {
        active.pause()
    }

    public func stop() {
        active.stop()
    }

    public func seek(to seconds: TimeInterval) {
        active.seek(to: seconds)
    }

    public func togglePlaying() {
        active.togglePlaying()
    }

    public func clear() {
        active.clear()
    }

    // MARK: - Queue Actions

    public func add(item: AudioItem, playWhenReady: Bool? = nil) {
        active.add(item: item, playWhenReady: playWhenReady)
    }

    public func add(items: [AudioItem], playWhenReady: Bool? = nil) {
        active.add(items: items, playWhenReady: playWhenReady)
    }

    public func next() {
        active.next()
    }

    public func previous() {
        active.previous()
    }
}