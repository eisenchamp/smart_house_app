// EmergencyManager.swift  — iPhone target

import SwiftUI
import AVFoundation
import Combine

class EmergencyManager: ObservableObject {
    @Published var countdown      = 10
    @Published var isCountingDown = false
    @Published var audioPlayer: AVAudioPlayer?

    private var countdownTimer: Timer?

    func startCountdown() {
        countdown = 10
        isCountingDown = true
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.countdown > 0 {
                    self.countdown -= 1
                } else {
                    self.isCountingDown = false
                    timer.invalidate()
                }
            }
        }
    }

    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdown = 10
        isCountingDown = false
    }

    func playSiren() {
        stopSiren()
        guard let url = Bundle.main.url(forResource: "siren", withExtension: "mp3") else {
            print("⚠️  siren.mp3 not found in bundle")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
            print("🔊 Siren playing")
        } catch {
            print("Siren error: \(error.localizedDescription)")
        }
    }

    func stopSiren() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
