// HealthData.swift  (shared between iPhone and Watch targets)

import Foundation

struct HealthData: Codable {
    var heartRate: Double = 0.0
    var spo2: Double = 0.0
    var temperature: Double = 36.5
    var age: Int = 30
    var gender: Int = 0   // 0 = Male, 1 = Female

    // Normalised feature vector fed into the model
    // Order must match training: [HR, SpO2, temp, age, gender]
    var featureVector: [Float] {
        [
            Float(heartRate / 200.0),
            Float(spo2 / 100.0),
            Float((temperature - 35.0) / 6.0),
            Float(age) / 100.0,
            Float(gender)
        ]
    }
}

// Prediction result sent back from the model
struct AnomalyResult {
    let classIndex: Int
    let confidence: Float
    let isAnomaly: Bool

    static let classLabels = [
        "Normal",
        "Tachycardia",
        "Bradycardia",
        "Low SpO₂",
        "Temperature Anomaly",
        "Multi-parameter Anomaly"
    ]

    var label: String { AnomalyResult.classLabels[classIndex] }
}
