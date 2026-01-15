import Foundation

public final class CrossfadeQueuedAudioPlayer {

    private let primary: QueuedAudioPlayer
    private let secondary: QueuedAudioPlayer

    private var active: QueuedAudioPlayer
    private var inactive: QueuedAudioPlayer

    public let event = AudioPlayer.EventHolder()

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

    private func bindEvents(from player: QueuedAudioPlayer) {
        player.event.stateChange.addListener(self) { [weak self] state in
            self?.event.stateChange.emit(data: state)
        }

        player.event.currentItem.addListener(self) { [weak self] data in
            self?.event.currentItem.emit(data: data)
        }

        player.event.secondElapse.addListener(self) { [weak self] seconds in
            self?.event.secondElapse.emit(data: seconds)
        }

        player.event.fail.addListener(self) { [weak self] error in
            self?.event.fail.emit(data: error)
        }

        player.event.playWhenReadyChange.addListener(self) { [weak self] value in
            self?.event.playWhenReadyChange.emit(data: value)
        }
    }
}