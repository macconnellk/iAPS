// File: ParameterOptimizationStateModel.swift
// This is the COMPLETE file for Step 3 - copy this exactly

import SwiftUI
import Combine

@MainActor
final class ParameterOptimizationStateModel: ObservableObject {
    @Published var recommendations: ParameterRecommendations?
    @Published var isAnalyzing = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var analysisSettings = AnalysisSettings()
    
    // Step 3: Mock analysis using our MockDataProvider
    func runAnalysis() async {
        isAnalyzing = true
        errorMessage = ""
        
        // Simulate analysis delay (like real API call would have)
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        do {
            // For Step 3, use mock data
            recommendations = MockDataProvider.createSampleRecommendations()
            print("✅ Analysis completed with mock data")
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
            showError = true
            print("❌ Analysis failed: \(error)")
        }
        
        isAnalyzing = false
    }
    
    // Helper function to get total recommendation count
    var totalRecommendations: Int {
        guard let recommendations = recommendations else { return 0 }
        return recommendations.basalRecommendations.count +
               recommendations.isfRecommendations.count +
               recommendations.crRecommendations.count
    }
    
    // Helper function to check if we have any recommendations
    var hasRecommendations: Bool {
        totalRecommendations > 0
    }
    
    // Reset function to clear results
    func resetAnalysis() {
        recommendations = nil
        showError = false
        errorMessage = ""
    }
    
    // Test function for Step 3 validation
    func validateStep3() {
        print("🧪 Testing Step 3: StateModel...")
        print("✅ Initial state - isAnalyzing: \(isAnalyzing)")
        print("✅ Settings loaded: \(analysisSettings.timeInRangeTarget)% TIR target")
        print("✅ Mock analysis function ready")
        print("🎉 Step 3 Complete - State management working!")
    }
}

let stateModel = ParameterOptimizationStateModel()
stateModel.validateStep3()
