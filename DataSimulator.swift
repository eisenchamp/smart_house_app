// DataSimulator.swift  (shared between iPhone and Watch targets)
// Generates synthetic health readings for testing the anomaly pipeline.

import Foundation

enum SimulationMode: String, CaseIterable {
    case normal            = "Normal (healthy)"
    case tachycardia       = "Tachycardia (high HR)"
    case bradycardia       = "Bradycardia (low HR)"
    case lowSpO2           = "Low SpO₂"
    case fever             = "Fever"
    case multiAnomaly      = "Multi-parameter anomaly"

    var description: String { rawValue }
}

class DataSimulator {

    // ── Public ────────────────────────────────────────────────────────────────

    static func makeSequence(
        mode: SimulationMode,
        length: Int = 30,
        age: Int = 30,
        gender: Int = 0
    ) -> [HealthData] {
        (0..<length).map { _ in makeReading(mode: mode, age: age, gender: gender) }
    }

    static func makeReading(
        mode: SimulationMode,
        age: Int = 30,
        gender: Int = 0
    ) -> HealthData {
        var d = HealthData()
        d.age    = age
        d.gender = gender

        switch mode {

        case .normal:
            d.heartRate   = jitter(base: 72,  spread: 8)
            d.spo2        = jitter(base: 98,  spread: 1)
            d.temperature = jitter(base: 36.6, spread: 0.2)

        case .tachycardia:
            d.heartRate   = jitter(base: 130, spread: 15)
            d.spo2        = jitter(base: 97,  spread: 1)
            d.temperature = jitter(base: 37.0, spread: 0.3)

        case .bradycardia:
            d.heartRate   = jitter(base: 42,  spread: 5)
            d.spo2        = jitter(base: 96,  spread: 1.5)
            d.temperature = jitter(base: 36.4, spread: 0.2)

        case .lowSpO2:
            d.heartRate   = jitter(base: 88,  spread: 10)
            d.spo2        = jitter(base: 88,  spread: 2)
            d.temperature = jitter(base: 36.5, spread: 0.2)

        case .fever:
            d.heartRate   = jitter(base: 100, spread: 8)
            d.spo2        = jitter(base: 96,  spread: 1)
            d.temperature = jitter(base: 39.2, spread: 0.4)

        case .multiAnomaly:
            d.heartRate   = jitter(base: 140, spread: 10)
            d.spo2        = jitter(base: 87,  spread: 2)
            d.temperature = jitter(base: 39.5, spread: 0.3)
        }

        return d
    }

    // ── Private helper ────────────────────────────────────────────────────────

    private static func jitter(base: Double, spread: Double) -> Double {
        base + Double.random(in: -spread...spread)
    }
}
