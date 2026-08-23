import Foundation
import Combine
import AVFoundation

// MARK: - Audio Manager

/// Manages Lumori's ambient soundtrack.
///
/// Two AVAudioPlayer instances alternate playback so the next copy of the
/// soundtrack begins before the current copy finishes. This creates a soft,
/// continuous loop instead of a noticeable restart.
///
/// The user's music preference is stored locally and persists between launches.
@MainActor
final class AudioManager: ObservableObject {

    // MARK: - Published State

    @Published private(set)
    var isPlaying = false

    @Published private(set)
    var isMusicEnabled: Bool

    // MARK: - Players

    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?

    private var activePlayerIsA = true

    private var loopTask: Task<Void, Never>?

    // MARK: - Configuration

    /// Lumori should feel ambient rather than like foreground music.
    private let targetVolume: Float = 0.22

    /// Start the next copy well before the current file ends.
    ///
    /// LumoriLoop has a long, quiet tail, so the incoming copy starts
    /// 25 seconds before the file technically reaches the end.
    private let overlapDuration: TimeInterval = 25.0

    /// The audible volume transition itself is shorter than the overlap.
    ///
    /// This keeps the crossfade from feeling overly slow while still masking
    /// the quiet tail at the end of the outgoing track.
    private let fadeDuration: TimeInterval = 7.0

    private let trackName = "LumoriLoop"
    private let trackExtension = "mp3"

    private let musicEnabledKey =
        "lumori.ambientMusicEnabled"

    // MARK: - Initialization

    init() {
        if UserDefaults.standard.object(
            forKey: musicEnabledKey
        ) == nil {

            // Music is enabled by default on a fresh installation.
            isMusicEnabled = true

        } else {

            isMusicEnabled =
                UserDefaults.standard.bool(
                    forKey: musicEnabledKey
                )
        }

        configureAudioSession()
        preparePlayers()
    }

    // MARK: - Preference

    /// Updates and persists the user's soundtrack preference.
    func setMusicEnabled(_ enabled: Bool) {
        isMusicEnabled = enabled

        UserDefaults.standard.set(
            enabled,
            forKey: musicEnabledKey
        )

        if enabled {
            play()
        } else {
            stop()
        }
    }

    // MARK: - Playback

    /// Starts the ambient soundtrack.
    ///
    /// Calling this repeatedly is safe.
    func play() {
        guard isMusicEnabled else {
            return
        }

        guard !isPlaying else {
            return
        }

        guard let playerA,
              let playerB else {

            print(
                "❌ Lumori soundtrack players are unavailable."
            )

            return
        }

        loopTask?.cancel()

        playerA.stop()
        playerB.stop()

        playerA.currentTime = 0
        playerB.currentTime = 0

        playerA.volume = 0
        playerB.volume = 0

        activePlayerIsA = true

        guard playerA.play() else {

            print(
                "❌ Lumori soundtrack could not begin playback."
            )

            return
        }

        playerA.setVolume(
            targetVolume,
            fadeDuration: 1.5
        )

        isPlaying = true

        scheduleNextCrossfade()

        print("🎵 Lumori soundtrack started")
    }

    /// Stops Lumori's soundtrack with a short fade.
    func stop() {
        guard isPlaying else {
            return
        }

        loopTask?.cancel()
        loopTask = nil

        playerA?.setVolume(
            0,
            fadeDuration: 0.5
        )

        playerB?.setVolume(
            0,
            fadeDuration: 0.5
        )

        let firstPlayer = playerA
        let secondPlayer = playerB

        Task {
            try? await Task.sleep(
                for: .milliseconds(550)
            )

            guard !Task.isCancelled else {
                return
            }

            firstPlayer?.stop()
            secondPlayer?.stop()

            firstPlayer?.currentTime = 0
            secondPlayer?.currentTime = 0

            firstPlayer?.volume = 0
            secondPlayer?.volume = 0
        }

        isPlaying = false

        print("🎵 Lumori soundtrack stopped")
    }

    /// Called when Lumori returns to the foreground.
    func resumeIfNeeded() {
        guard isMusicEnabled else {
            return
        }

        play()
    }

    // MARK: - Crossfade Loop

    private func scheduleNextCrossfade() {
        loopTask?.cancel()

        guard let activePlayer else {
            return
        }

        let duration = activePlayer.duration

        guard duration > 0 else {
            return
        }

        /*
         Example:

         Track duration: 120 sec
         Overlap:        17 sec

         Incoming copy begins at 103 sec.

         The incoming copy then fades in over 7 sec while the outgoing
         copy fades down over the same 7 sec.
         */

        let delay = max(
            duration - overlapDuration,
            0.1
        )

        loopTask = Task { [weak self] in

            try? await Task.sleep(
                for: .seconds(delay)
            )

            guard !Task.isCancelled,
                  let self else {
                return
            }

            await self.performCrossfade()
        }
    }

    private func performCrossfade() async {
        guard isPlaying,
              isMusicEnabled,
              let outgoingPlayer = activePlayer,
              let incomingPlayer = inactivePlayer else {

            return
        }

        // Prepare the incoming copy from the beginning.
        incomingPlayer.stop()
        incomingPlayer.currentTime = 0
        incomingPlayer.volume = 0

        guard incomingPlayer.play() else {

            print(
                "❌ Lumori could not begin the next soundtrack loop."
            )

            return
        }

        // Fade the new copy in while the old copy fades down.
        incomingPlayer.setVolume(
            targetVolume,
            fadeDuration: fadeDuration
        )

        outgoingPlayer.setVolume(
            0,
            fadeDuration: fadeDuration
        )

        // Incoming player becomes the active track.
        activePlayerIsA.toggle()

        // Schedule the next transition based on the incoming copy.
        scheduleNextCrossfade()

        /*
         Keep the outgoing file alive through the remaining overlap.
         Even though its volume fade finishes after 7 seconds, the extra
         overlap helps avoid exposing the silent tail of the MP3.
         */
        try? await Task.sleep(
            for: .seconds(
                overlapDuration + 0.25
            )
        )

        guard !Task.isCancelled else {
            return
        }

        outgoingPlayer.stop()
        outgoingPlayer.currentTime = 0
        outgoingPlayer.volume = 0
    }

    // MARK: - Player Selection

    private var activePlayer: AVAudioPlayer? {
        activePlayerIsA
            ? playerA
            : playerB
    }

    private var inactivePlayer: AVAudioPlayer? {
        activePlayerIsA
            ? playerB
            : playerA
    }

    // MARK: - Preparation

    private func preparePlayers() {
        guard let url = Bundle.main.url(
            forResource: trackName,
            withExtension: trackExtension
        ) else {

            print(
                "❌ Could not find \(trackName).\(trackExtension) in the Lumori bundle."
            )

            return
        }

        do {
            playerA = try AVAudioPlayer(
                contentsOf: url
            )

            playerB = try AVAudioPlayer(
                contentsOf: url
            )

            playerA?.prepareToPlay()
            playerB?.prepareToPlay()

            playerA?.volume = 0
            playerB?.volume = 0

            // Built-in looping is disabled because Lumori crossfades manually.
            playerA?.numberOfLoops = 0
            playerB?.numberOfLoops = 0

            print("🎵 Lumori soundtrack ready")
            print(
                "Duration:",
                playerA?.duration ?? 0
            )

        } catch {

            print(
                "❌ Failed to prepare Lumori soundtrack:"
            )

            print(
                error.localizedDescription
            )
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session =
                AVAudioSession.sharedInstance()

            try session.setCategory(
                .ambient,
                mode: .default,
                options: [
                    .mixWithOthers
                ]
            )

            try session.setActive(true)

        } catch {

            print(
                "⚠️ Lumori audio session could not be configured:"
            )

            print(
                error.localizedDescription
            )
        }
    }
}
