// AnomalyDetector.swift
// Runs the CoreML model (HealthAnomalyDetector.mlpackage) on a sliding window
// of health readings and returns an AnomalyResult.
//
// Add HealthAnomalyDetector.mlpackage to BOTH the iPhone and Apple Watch targets
// in Xcode so each device can run inference locally.

import CoreML
import Foundation

class AnomalyDetector {

    static let shared = AnomalyDetector()

    // ── Configuration ────────────────────────────────────────────────────────
    private let sequenceLength = 30   // must match convert_to_coreml.py SEQ_LEN
    private let featureCount   = 5
    private let anomalyThreshold: Float = 0.5  // min confidence to declare anomaly

    // ── State ─────────────────────────────────────────────────────────────────
    private var window: [[Float]] = []
    private var model: MLModel?

    // ── Init ──────────────────────────────────────────────────────────────────
    private init() {
        loadModel()
    }

    private func loadModel() {
        guard let url = Bundle.main.url(
            forResource: "HealthAnomalyDetector",
            withExtension: "mlpackage"
        ) else {
            print("⚠️  HealthAnomalyDetector.mlpackage not found in bundle")
            print("    Run ModelConversion/convert_to_coreml.py first,")
            print("    then add the .mlpackage to both Xcode targets.")
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            model = try MLModel(contentsOf: url, configuration: config)
            print("✅ AnomalyDetector: model loaded")
        } catch {
            print("❌ AnomalyDetector: failed to load model — \(error.localizedDescription)")
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /// Feed one reading into the sliding window; returns a result once
    /// the window is full (nil while still accumulating).
    func addReading(_ data: HealthData) -> AnomalyResult? {
        window.append(data.featureVector)
        if window.count > sequenceLength { window.removeFirst() }
        guard window.count == sequenceLength else { return nil }
        return predict()
    }

    /// Run inference on the current full window immediately.
    func predict() -> AnomalyResult? {
        guard window.count == sequenceLength else { return nil }

        // ── Simulation fallback (no CoreML model present) ─────────────────
        guard let model = model else {
            return simulatePrediction()
        }

        // ── Build MLMultiArray [1, seqLen, featureCount] ──────────────────
        guard let inputArray = try? MLMultiArray(
            shape: [1, sequenceLength as NSNumber, featureCount as NSNumber],
            dataType: .float32
        ) else { return nil }

        for (t, features) in window.enumerated() {
            for (f, value) in features.enumerated() {
                let idx = t * featureCount + f
                inputArray[idx] = NSNumber(value: value)
            }
        }

        let inputFeatures = try? MLDictionaryFeatureProvider(
            dictionary: ["input": inputArray]
        )
        guard let features = inputFeatures,
              let result = try? model.prediction(from: features),
              let outputArray = result.featureValue(for: "output")?.multiArrayValue
        else { return nil }

        // Softmax over raw logits
        var logits = (0..<6).map { Float(truncating: outputArray[$0]) }
        let maxLogit = logits.max()!
        var exps = logits.map { exp($0 - maxLogit) }
        let sumExp = exps.reduce(0, +)
        let probs  = exps.map { $0 / sumExp }

        let classIndex = probs.indices.max(by: { probs[$0] < probs[$1] })!
        let confidence = probs[classIndex]
        let isAnomaly  = (classIndex != 0) && (confidence >= anomalyThreshold)

        print("🔍 Model prediction: class=\(classIndex) (\(AnomalyResult.classLabels[classIndex])), confidence=\(String(format:"%.2f", confidence))")

        return AnomalyResult(
            classIndex: classIndex,
            confidence: confidence,
            isAnomaly: isAnomaly
        )
    }

    // ── Simulation fallback ───────────────────────────────────────────────────
    /// Used when the CoreML model file is not present, or during development.
    private func simulatePrediction() -> AnomalyResult {
        // Look at the last reading to make a rule-based "prediction"
        guard let last = window.last else {
            return AnomalyResult(classIndex: 0, confidence: 0.95, isAnomaly: false)
        }
        // Denormalise
        let hr   = Double(last[0]) * 200.0
        let spo2 = Double(last[1]) * 100.0
        let temp = Double(last[2]) * 6.0 + 35.0

        var classIndex = 0
        if hr > 100        { classIndex = 1 }  // Tachycardia
        else if hr < 50    { classIndex = 2 }  // Bradycardia
        else if spo2 < 92  { classIndex = 3 }  // Low SpO2
        else if temp > 38  { classIndex = 4 }  // Fever

        let confidence: Float = classIndex == 0 ? 0.93 : 0.87
        let isAnomaly = classIndex != 0

        print("🔍 [SIMULATED] prediction: class=\(classIndex) (\(AnomalyResult.classLabels[classIndex])), confidence=\(String(format:"%.2f", confidence))")
        return AnomalyResult(classIndex: classIndex, confidence: confidence, isAnomaly: isAnomaly)
    }

    func resetWindow() { window.removeAll() }
}
