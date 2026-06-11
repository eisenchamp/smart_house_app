// WatchSessionManager.swift  — Apple Watch target
// Handles health data collection, model inference, and the emergency alert flow.

import WatchConnectivity
import Combine
import WatchKit

class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {

    // ── Published state ───────────────────────────────────────────────────────
    @Published var healthData      = HealthData()
    @Published var showAlert       = false
    @Published var predictionLabel = "Waiting…"
    @Published var isMonitoring    = false

    // ── Internal state ────────────────────────────────────────────────────────
    var anomalyId: String?
    var canSendECG = true
    private var simulationTimer: Timer?

    // ── Init ──────────────────────────────────────────────────────────────────
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // ── Simulation control ────────────────────────────────────────────────────

    func startSimulation(mode: SimulationMode) {
        stopSimulation()
        isMonitoring = true
        AnomalyDetector.shared.resetWindow()
        print("▶️  Simulation started: \(mode.description)")

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.canSendECG else { return }

            let reading = DataSimulator.makeReading(
                mode: mode,
                age: self.healthData.age,
                gender: self.healthData.gender
            )
            DispatchQueue.main.async {
                self.healthData = reading
            }

            if let result = AnomalyDetector.shared.addReading(reading) {
                DispatchQueue.main.async {
                    self.predictionLabel = "\(result.label) (\(Int(result.confidence * 100))%)"
                    print("📊 HR=\(Int(reading.heartRate)) SpO2=\(Int(reading.spo2))% Temp=\(String(format:"%.1f",reading.temperature))°C → \(result.label)")
                }

                if result.isAnomaly {
                    self.triggerAnomalyAlert(result: result)
                }
            }
        }
    }

    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        isMonitoring = false
        print("⏹  Simulation stopped")
    }

    // ── ECG / live data path (for real HealthKit use) ─────────────────────────

    func sendNextECGRow() {
        guard canSendECG else { return }
        if let result = AnomalyDetector.shared.addReading(healthData) {
            predictionLabel = "\(result.label) (\(Int(result.confidence * 100))%)"
            if result.isAnomaly { triggerAnomalyAlert(result: result) }
        }
    }

    // ── Alert flow ────────────────────────────────────────────────────────────

    private func triggerAnomalyAlert(result: AnomalyResult) {
        guard !showAlert else { return }   // don't stack alerts

        canSendECG = false
        anomalyId  = UUID().uuidString

        print("🚨 Anomaly detected: \(result.label) — showing alert (id=\(anomalyId!))")

        // Haptic on the watch
        WKInterfaceDevice.current().play(.notification)

        DispatchQueue.main.async {
            self.showAlert = true
        }

        // Auto-escalate after 10 s if no response
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, self.showAlert else { return }
            print("⏰ No response within 10 s — escalating to emergency")
            self.showAlert = false
            self.sendEmergencyAlert()
        }
    }

    func userRespondedOkay() {
        showAlert = false
        canSendECG = true
        print("✅ User confirmed okay — resuming monitoring")
        WKInterfaceDevice.current().play(.success)
        sendFeedback(okay: true)
    }

    func userRespondedNotOkay() {
        showAlert = false
        print("❗ User is NOT okay — sending emergency alert")
        sendEmergencyAlert()
        sendFeedback(okay: false)
    }

    // ── Emergency signal ──────────────────────────────────────────────────────

    func sendEmergencyAlert() {
        print("🆘 EMERGENCY ALERT SENT")
        WKInterfaceDevice.current().play(.failure)

        // Tell the iPhone
        sendMessageToPhone(["emergency": true, "anomalyId": anomalyId ?? "manual"])
    }

    // ── WatchConnectivity ─────────────────────────────────────────────────────

    private func sendMessageToPhone(_ message: [String: Any]) {
        guard WCSession.default.isReachable else {
            print("📵 iPhone not reachable — message queued")
            return
        }
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("WC send error: \(error.localizedDescription)")
        }
    }

    private func sendFeedback(okay: Bool) {
        guard let id = anomalyId else { return }
        sendMessageToPhone(["feedback": okay ? 0 : 1, "anomalyId": id])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let hr  = message["heartRate"]   as? Double { self.healthData.heartRate   = hr  }
            if let sp  = message["spo2"]        as? Double { self.healthData.spo2        = sp  }
            if let tmp = message["temperature"] as? Double { self.healthData.temperature = tmp }
            if let age = message["age"]         as? Int    { self.healthData.age         = age }
            if let g   = message["gender"]      as? Int    { self.healthData.gender      = g   }
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if let error = error { print("WC activation error: \(error.localizedDescription)") }
    }
}
