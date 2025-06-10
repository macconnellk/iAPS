// File: MockDataProvider.swift
// This is the COMPLETE file for Step 2 - copy this exactly

import Foundation

class MockDataProvider {
    static func createSampleAnalysisData() -> ParameterAnalysisData {
        let now = Date()
        
        let glucoseReadings = [
            GlucoseReading(date: now.addingTimeInterval(-3600), sgv: 120, direction: "Flat", isValid: true, isPressureLow: false),
            GlucoseReading(date: now.addingTimeInterval(-3300), sgv: 135, direction: "SlightlyUp", isValid: true, isPressureLow: false),
            GlucoseReading(date: now.addingTimeInterval(-3000), sgv: 140, direction: "Flat", isValid: true, isPressureLow: false),
            GlucoseReading(date: now.addingTimeInterval(-2700), sgv: 85, direction: "Down", isValid: true, isPressureLow: false),
            GlucoseReading(date: now.addingTimeInterval(-2400), sgv: 75, direction: "Down", isValid: true, isPressureLow: false),
            GlucoseReading(date: now.addingTimeInterval(-2100), sgv: 110, direction: "Up", isValid: true, isPressureLow: false)
        ]
        
        let treatments = [
            TreatmentData(date: now.addingTimeInterval(-7200), type: .carbs, carbs: 45, insulin: nil, iob: nil),
            TreatmentData(date: now.addingTimeInterval(-3600), type: .bolus, carbs: nil, insulin: 2.5, iob: nil)
        ]
        
        let currentParameters = CurrentParameters(
            basalRates: [
                BasalRate(start: "00:00", rate: 1.0, minutes: 0),
                BasalRate(start: "06:00", rate: 1.2, minutes: 360),
                BasalRate(start: "12:00", rate: 0.8, minutes: 720),
                BasalRate(start: "18:00", rate: 1.1, minutes: 1080)
            ],
            isfProfile: [
                ISFEntry(start: "00:00", sensitivity: 50, offset: 0),
                ISFEntry(start: "06:00", sensitivity: 45, offset: 360),
                ISFEntry(start: "12:00", sensitivity: 55, offset: 720),
                ISFEntry(start: "18:00", sensitivity: 50, offset: 1080)
            ],
            crProfile: [
                CREntry(start: "00:00", ratio: 12, offset: 0),
                CREntry(start: "06:00", ratio: 10, offset: 360),
                CREntry(start: "12:00", ratio: 8, offset: 720),
                CREntry(start: "18:00", ratio: 10, offset: 1080)
            ],
            csfRange: 6.0...12.0
        )
        
        let deviceStatus = [
            DeviceStatus(date: now.addingTimeInterval(-300), iob: 0.1, basalIOB: 0.05, bolusIOB: 0.05),
            DeviceStatus(date: now.addingTimeInterval(-600), iob: -0.1, basalIOB: -0.15, bolusIOB: 0.05),
            DeviceStatus(date: now, iob: 0.2, basalIOB: 0.1, bolusIOB: 0.1)
        ]
        
        return ParameterAnalysisData(
            timestamp: now,
            glucoseReadings: glucoseReadings,
            treatments: treatments,
            currentParameters: currentParameters,
            deviceStatus: deviceStatus,
            parameterHistory: []
        )
    }
    
    static func createSampleRecommendations() -> ParameterRecommendations {
        let safetyMetrics = SafetyMetrics(
            timeBelow70: 2.5,
            timeInRange70_160: 85.0,
            glucoseStandardDeviation: 45.0,
            averageGlucose: 140.0,
            totalLowEvents: 3,
            severeLowEvents: 0
        )
        
        let excludedData = ExcludedDataSummary(
            totalExcluded: 5,
            pressureLows: 3,
            invalidReadings: 2,
            excludedTimes: [Date().addingTimeInterval(-7200)]
        )
        
        let basalRecommendation = BasalRecommendation(
            timeBlock: "02:00 - 06:00",
            currentRate: 1.0,
            recommendedRate: 1.1,
            changePercentage: 10.0,
            reason: "Negative basal IOB (-0.15U) with low glucose (85 mg/dL) detected at 3:00 AM. Increasing basal rate to prevent future lows.",
            detectionTime: Date().addingTimeInterval(-3000),
            basalIOB: -0.15,
            glucoseValue: 85,
            priority: .high
        )
        
        let crRecommendation = CRRecommendation(
            timeBlock: "12:00 - 16:00",
            currentCR: 8.0,
            recommendedCR: 7.5,
            changePercentage: -6.25,
            reason: "Post-meal glucose peak of 190 mg/dL suggests insufficient carb coverage for lunch period.",
            mealTime: Date().addingTimeInterval(-7200),
            glucoseExcursion: 50,
            associatedISF: 55.0,
            csfBefore: 6.875,
            csfAfter: 7.33,
            priority: .medium
        )
        
        return ParameterRecommendations(
            analysisDate: Date(),
            basalRecommendations: [basalRecommendation],
            isfRecommendations: [],
            crRecommendations: [crRecommendation],
            safetyMetrics: safetyMetrics,
            excludedData: excludedData
        )
    }
    
    // Test function for Step 2 validation
    static func validateStep2() {
        print("🧪 Testing Step 2: MockDataProvider...")
        
        let analysisData = createSampleAnalysisData()
        print("✅ Created analysis data with \(analysisData.glucoseReadings.count) glucose readings")
        print("✅ Created \(analysisData.treatments.count) treatments")
        print("✅ Created \(analysisData.currentParameters.basalRates.count) basal rates")
        
        let recommendations = createSampleRecommendations()
        print("✅ Created recommendations with \(recommendations.basalRecommendations.count) basal recommendations")
        print("✅ Created recommendations with \(recommendations.crRecommendations.count) CR recommendations")
        print("✅ Safety metrics: \(recommendations.safetyMetrics.timeInRange70_160)% TIR")
        
        print("🎉 Step 2 Complete - Mock data working perfectly!")
    }
}

// Temporary test - call this somewhere
MockDataProvider.validateStep2()
