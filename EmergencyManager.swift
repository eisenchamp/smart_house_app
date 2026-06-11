// EmergencyManager.swift  — Apple Watch target

import SwiftUI
import AVFoundation
import WatchKit
import Combine

class EmergencyManager: ObservableObject {
    @Published var countdown      = 10
    @Published var isCountingDown = false

    private var countdownTimer: Timer?
    private var audioPlayer: AVAudioPlayer?

    func startCountdown() {
        countdown = 10
        isCountingDown = true
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.countdown > 0 {
                    self.countdown -= 1
                    WKInterfaceDevice.current().play(.click)
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
        // On watchOS, haptics replace audio — using a looping haptic pattern instead
        // If you bundle a "siren.wav" in the Watch target, AVAudioPlayer will use it
        if let url = Bundle.main.url(forResource: "siren", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.play()
            } catch {
                print("Siren audio error: \(error.localizedDescription)")
            }
        } else {
            // Fallback: strong haptic sequence
            WKInterfaceDevice.current().play(.failure)
        }
    }

    func stopSiren() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
