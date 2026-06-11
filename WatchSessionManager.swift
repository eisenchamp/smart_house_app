// WatchSessionManager.swift  — iPhone target
// The iPhone side: receives health data and emergency signals from the Watch,
// and can trigger sounds / notifications on the phone side.

import WatchConnectivity
import Combine
import UIKit
import UserNotifications
import AVFoundation

class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {

    @Published var healthData        = HealthData()
    @Published var showAlert         = false
    @Published var predictionLabel   = "Waiting for Watch data…"
    @Published var lastEmergencyTime: Date?

    var anomalyId: String?
    var canSendECG = true

    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        requestNotificationPermission()
    }

    // ── Notification permission ───────────────────────────────────────────────
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            print(granted ? "✅ Notifications granted" : "❌ Notifications denied: \(error?.localizedDescription ?? "")")
        }
    }

    // ── WatchConnectivity: receive messages from Watch ────────────────────────
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            // Health readings
            if let hr  = message["heartRate"]   as? Double { self.healthData.heartRate   = hr  }
            if let sp  = message["spo2"]        as? Double { self.healthData.spo2        = sp  }
            if let tmp = message["temperature"] as? Double { self.healthData.temperature = tmp }

            // Emergency signal from Watch
            if let isEmergency = message["emergency"] as? Bool, isEmergency {
                let id = message["anomalyId"] as? String ?? "unknown"
                print("🆘 Emergency received from Watch (id=\(id))")
                self.handleEmergency(anomalyId: id)
            }

            // Feedback from Watch user ("okay" or "not okay")
            if let feedback = message["feedback"] as? Int,
               let id = message["anomalyId"] as? String {
                print("📩 Feedback from Watch: \(feedback == 0 ? "okay" : "not okay") (id=\(id))")
                if feedback == 1 { self.handleEmergency(anomalyId: id) }
            }
        }
    }

    // ── Emergency handling ────────────────────────────────────────────────────
    private func handleEmergency(anomalyId: String) {
        self.anomalyId = anomalyId
        lastEmergencyTime = Date()
        showAlert = true
        playSiren()
        sendLocalNotification(anomalyId: anomalyId)
    }

    func sendEmergencyAlert() {
        handleEmergency(anomalyId: UUID().uuidString)
        // Also tell the Watch
        let msg: [String: Any] = ["emergency": true, "anomalyId": anomalyId ?? ""]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        }
    }

    func sendFeedbackForAnomaly(anomalyId: String, feedback: Int) {
        print("Sending feedback \(feedback) for anomaly \(anomalyId)")
    }

    // ── Local notification ────────────────────────────────────────────────────
    private func sendLocalNotification(anomalyId: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Health Emergency"
        content.body  = "An anomaly was detected. Tap to respond."
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: anomalyId,
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }

    // ── Siren ────────────────────────────────────────────────────────────────
    func playSiren() {
        stopSiren()
        if let url = Bundle.main.url(forResource: "siren", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.play()
            } catch {
                print("Siren error: \(error.localizedDescription)")
            }
        } else {
            // Play system sound as fallback
            AudioServicesPlaySystemSound(1005)
        }
    }

    func stopSiren() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // ── WCSession boilerplate ─────────────────────────────────────────────────
    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if let error = error { print("WC error: \(error.localizedDescription)") }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
