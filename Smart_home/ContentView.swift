// ContentView.swift  — iPhone target
// Shows live data mirrored from the Watch, and handles emergency alerts.

import SwiftUI
import AVFoundation
import Combine

struct ContentView: View {

    @StateObject private var sessionManager  = WatchSessionManager()
    @StateObject private var emergencyManager = EmergencyManager()
    @StateObject private var healthManager   = HealthManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                // ── Vitals card ───────────────────────────────────────────
                GroupBox("Health Vitals (from Watch)") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "heart.fill").foregroundColor(.red)
                            Text("Heart Rate: \(Int(sessionManager.healthData.heartRate)) BPM")
                        }
                        HStack {
                            Image(systemName: "waveform.path.ecg").foregroundColor(.blue)
                            Text(String(format: "SpO₂: %.1f%%", sessionManager.healthData.spo2))
                        }
                        HStack {
                            Image(systemName: "thermometer").foregroundColor(.orange)
                            Text(String(format: "Temp: %.1f°C", sessionManager.healthData.temperature))
                        }
                        HStack {
                            Image(systemName: "person.fill").foregroundColor(.purple)
                            Text("Age: \(sessionManager.healthData.age)  Gender: \(sessionManager.healthData.gender == 0 ? "M" : "F")")
                        }
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }

                // ── Status ────────────────────────────────────────────────
                GroupBox("Model Status") {
                    Text(sessionManager.predictionLabel)
                        .foregroundColor(sessionManager.predictionLabel.hasPrefix("Normal") ? .green : .red)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // ── Emergency countdown ───────────────────────────────────
                if emergencyManager.isCountingDown {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text("Emergency in \(emergencyManager.countdown) seconds!")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }

                Spacer()

                // ── Manual SOS ────────────────────────────────────────────
                Button {
                    sessionManager.sendEmergencyAlert()
                    emergencyManager.startCountdown()
                    emergencyManager.playSiren()
                } label: {
                    Label("Manual SOS", systemImage: "sos")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.headline)
                }
            }
            .padding()
            .navigationTitle("Health Monitor")
        }
        // ── Emergency alert from Watch ────────────────────────────────────────
        .alert("⚠️ Health Emergency", isPresented: $sessionManager.showAlert) {
            Button("I'm Okay") {
                handleUserResponse(feedback: 0)
            }
            Button("I Need Help", role: .destructive) {
                handleUserResponse(feedback: 1)
            }
        } message: {
            Text("Anomaly detected on Watch.\nAre you okay?\n\nAuto-escalate in \(emergencyManager.countdown)s.")
                .onAppear {
                    emergencyManager.startCountdown()
                    emergencyManager.playSiren()
                }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if emergencyManager.isCountingDown, emergencyManager.countdown > 0 {
                emergencyManager.countdown -= 1
            }
        }
    }

    private func handleUserResponse(feedback: Int) {
        emergencyManager.stopSiren()
        emergencyManager.stopCountdown()
        sessionManager.stopSiren()
        if let id = sessionManager.anomalyId {
            sessionManager.sendFeedbackForAnomaly(anomalyId: id, feedback: feedback)
        }
        sessionManager.showAlert = false
        sessionManager.canSendECG = true

        if feedback == 1 {
            print("📞 User needs help — in production: call emergency services here")
        }
    }
}
