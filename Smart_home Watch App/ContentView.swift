// ContentView.swift  — Apple Watch target

import SwiftUI
import Combine

struct ContentView: View {

    @StateObject private var session = WatchSessionManager()
    @StateObject private var emergency = EmergencyManager()

    @State private var selectedMode: SimulationMode = .normal
    @State private var showModePicker = false

    // ── Body ──────────────────────────────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {

                // ── Vitals ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "\(Int(session.healthData.heartRate)) BPM",
                        systemImage: "heart.fill"
                    )
                    .foregroundColor(.red)

                    Label(
                        String(format: "%.1f%%", session.healthData.spo2),
                        systemImage: "waveform.path.ecg"
                    )
                    .foregroundColor(.blue)

                    Label(
                        String(format: "%.1f°C", session.healthData.temperature),
                        systemImage: "thermometer"
                    )
                    .foregroundColor(.orange)
                }
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

                // ── Prediction ────────────────────────────────────────────
                Text(session.predictionLabel)
                    .font(.system(size: 13))
                    .foregroundColor(session.predictionLabel.hasPrefix("Normal") ? .green : .yellow)
                    .multilineTextAlignment(.center)

                // ── Simulation mode picker ────────────────────────────────
                Button {
                    showModePicker = true
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text(selectedMode == .normal ? "Normal" : "Anomaly: \(selectedMode.description.split(separator:"(").first ?? "")")
                            .lineLimit(1)
                    }
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                // ── Start / Stop ──────────────────────────────────────────
                HStack(spacing: 8) {
                    if session.isMonitoring {
                        Button("Stop") {
                            session.stopSimulation()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    } else {
                        Button("Start") {
                            session.startSimulation(mode: selectedMode)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    Button("SOS") {
                        session.sendEmergencyAlert()
                        emergency.playSiren()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }

                // ── Emergency countdown ───────────────────────────────────
                if emergency.isCountingDown {
                    Text("Emergency in \(emergency.countdown)s")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        // ── Alert: are you okay? ──────────────────────────────────────────────
        .alert("⚠️ Anomaly Detected", isPresented: $session.showAlert) {
            Button("I'm Okay") {
                session.userRespondedOkay()
                emergency.stopSiren()
                emergency.stopCountdown()
            }
            Button("Need Help", role: .destructive) {
                session.userRespondedNotOkay()
                emergency.stopSiren()
                emergency.stopCountdown()
            }
        } message: {
            Text("Are you feeling okay?\nRespond within \(emergency.countdown) seconds.")
                .onAppear {
                    emergency.startCountdown()
                    emergency.playSiren()
                }
        }
        // ── Mode picker sheet ─────────────────────────────────────────────────
        .sheet(isPresented: $showModePicker) {
            List(SimulationMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                    showModePicker = false
                } label: {
                    HStack {
                        Text(mode.description)
                            .font(.system(size: 13))
                        Spacer()
                        if mode == selectedMode {
                            Image(systemName: "checkmark").foregroundColor(.green)
                        }
                    }
                }
            }
        }
        // ── Receive messages from iPhone ──────────────────────────────────────
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if emergency.isCountingDown, emergency.countdown > 0 {
                emergency.countdown -= 1
            }
        }
    }
}
