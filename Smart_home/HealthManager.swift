// HealthManager.swift  — iPhone target
// Reads live HealthKit data from the iPhone's own store.
// The Watch's HealthManager (same file) reads from the Watch store.

import HealthKit
import Combine

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var healthData = HealthData()

    func startLiveHealthUpdates() {
        requestAuthorization()
        fetchUserDetails()
        startLiveHeartRateUpdates()
        startLiveSpO2Updates()
    }

    private func requestAuthorization() {
        let healthTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!
        ]
        healthStore.requestAuthorization(toShare: nil, read: healthTypes) { success, error in
            if !success { print("HealthKit auth denied: \(error?.localizedDescription ?? "")") }
        }
    }

    private func fetchUserDetails() {
        do {
            if let dob = try healthStore.dateOfBirthComponents().date {
                let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                DispatchQueue.main.async { self.healthData.age = age }
            }
            let sex = try healthStore.biologicalSex().biologicalSex
            DispatchQueue.main.async { self.healthData.gender = sex == .female ? 1 : 0 }
        } catch { print("User details error: \(error.localizedDescription)") }
    }

    private func startLiveHeartRateUpdates() {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        healthStore.execute(createLiveQuery(for: type) { bpm in
            DispatchQueue.main.async {
                self.healthData.heartRate = bpm
                self.healthData.temperature = 36.5 + max(0, bpm - 70) * (0.5 / 20.0)
            }
        })
    }

    private func startLiveSpO2Updates() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        healthStore.execute(createLiveQuery(for: type) { pct in
            DispatchQueue.main.async { self.healthData.spo2 = pct * 100 }
        })
    }

    private func createLiveQuery(for type: HKQuantityType,
                                 updateHandler: @escaping (Double) -> Void) -> HKQuery {
        let unit: HKUnit = type.identifier == HKQuantityTypeIdentifier.heartRate.rawValue
            ? HKUnit(from: "count/min") : .percent()

        let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: nil,
                                          limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            guard let sample = (samples as? [HKQuantitySample])?.last else { return }
            updateHandler(sample.quantity.doubleValue(for: unit))
        }
        query.updateHandler = { _, samples, _, _, _ in
            guard let sample = (samples as? [HKQuantitySample])?.last else { return }
            updateHandler(sample.quantity.doubleValue(for: unit))
        }
        return query
    }
}
