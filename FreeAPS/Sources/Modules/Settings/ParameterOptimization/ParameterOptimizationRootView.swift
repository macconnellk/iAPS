// File: ParameterOptimizationRootView.swift
// Replace the ENTIRE contents with this:

import SwiftUI
import Swinject

extension Settings {
    enum ParameterOptimization {}
}

extension Settings.ParameterOptimization {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject private var state = ParameterOptimizationStateModel()
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Parameter Optimization")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("AI-powered analysis of your diabetes management parameters")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // Analysis Button
                        VStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await state.runAnalysis()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .font(.title2)
                                    Text("Analyze Parameters")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(state.isAnalyzing)
                            
                            if state.isAnalyzing {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Analyzing your data...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Results Section
                        if let recommendations = state.recommendations {
                            ResultsCard(recommendations: recommendations)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Analysis Error", isPresented: $state.showError) {
                Button("OK") { }
            } message: {
                Text(state.errorMessage)
            }
            .onAppear(perform: configureView)
        }
    }
    
    // MARK: - Results Card and other views (same as before)
    
    struct ResultsCard: View {
        let recommendations: ParameterRecommendations
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Analysis Results")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Summary Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("📊 Analysis Summary")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("✅ Analysis completed at \(DateFormatter.shortTime.string(from: recommendations.analysisDate))")
                        Text("📋 \(totalRecommendations) recommendations generated")
                        Text("📈 Safety metrics calculated")
                        
                        if recommendations.excludedData.totalExcluded > 0 {
                            Text("⚠️ \(recommendations.excludedData.totalExcluded) data points excluded")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                // Safety Metrics
                SafetyMetricsSection(metrics: recommendations.safetyMetrics)
                
                // Recommendations
                if hasRecommendations {
                    RecommendationsSection(recommendations: recommendations)
                } else {
                    NoRecommendationsSection()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        
        private var totalRecommendations: Int {
            recommendations.basalRecommendations.count +
            recommendations.isfRecommendations.count +
            recommendations.crRecommendations.count
        }
        
        private var hasRecommendations: Bool {
            totalRecommendations > 0
        }
    }
    
    // MARK: - Safety Metrics Section
    
    struct SafetyMetricsSection: View {
        let metrics: SafetyMetrics
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("🛡️ Safety Metrics")
                    .font(.headline)
                    .foregroundColor(.green)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    MetricCard(
                        title: "Time in Range",
                        value: "\(metrics.timeInRange70_160, specifier: "%.0f")%",
                        target: "Target: >70%",
                        color: metrics.timeInRange70_160 > 70 ? .green : .orange
                    )
                    
                    MetricCard(
                        title: "Time Below 70",
                        value: "\(metrics.timeBelow70, specifier: "%.1f")%",
                        target: "Target: <4%",
                        color: metrics.timeBelow70 < 4 ? .green : .red
                    )
                    
                    MetricCard(
                        title: "Glucose Std Dev",
                        value: "\(metrics.glucoseStandardDeviation, specifier: "%.0f")",
                        target: "Target: <36",
                        color: metrics.glucoseStandardDeviation < 36 ? .green : .orange
                    )
                    
                    MetricCard(
                        title: "Severe Lows",
                        value: "\(metrics.severeLowEvents)",
                        target: "Target: 0",
                        color: metrics.severeLowEvents == 0 ? .green : .red
                    )
                }
            }
        }
    }
    
    struct MetricCard: View {
        let title: String
        let value: String
        let target: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(target)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Other supporting views
    
    struct RecommendationsSection: View {
        let recommendations: ParameterRecommendations
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("💡 Recommendations")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    ForEach(recommendations.basalRecommendations.indices, id: \.self) { index in
                        BasalRecommendationCard(recommendation: recommendations.basalRecommendations[index])
                    }
                    
                    ForEach(recommendations.crRecommendations.indices, id: \.self) { index in
                        CRRecommendationCard(recommendation: recommendations.crRecommendations[index])
                    }
                    
                    ForEach(recommendations.isfRecommendations.indices, id: \.self) { index in
                        ISFRecommendationCard(recommendation: recommendations.isfRecommendations[index])
                    }
                }
            }
        }
    }
    
    struct BasalRecommendationCard: View {
        let recommendation: BasalRecommendation
        
        var body: some View {
            RecommendationCard(
                title: "🔧 Basal Rate (\(recommendation.timeBlock))",
                priority: recommendation.priority,
                currentValue: "\(recommendation.currentRate, specifier: "%.2f") U/hr",
                recommendedValue: "\(recommendation.recommendedRate, specifier: "%.2f") U/hr",
                change: "\(recommendation.changePercentage > 0 ? "+" : "")\(recommendation.changePercentage, specifier: "%.1f")%",
                reason: recommendation.reason
            )
        }
    }
    
    struct CRRecommendationCard: View {
        let recommendation: CRRecommendation
        
        var body: some View {
            RecommendationCard(
                title: "🍽️ Carb Ratio (\(recommendation.timeBlock))",
                priority: recommendation.priority,
                currentValue: "1:\(recommendation.currentCR, specifier: "%.1f")g",
                recommendedValue: "1:\(recommendation.recommendedCR, specifier: "%.1f")g",
                change: "\(recommendation.changePercentage > 0 ? "+" : "")\(recommendation.changePercentage, specifier: "%.1f")%",
                reason: recommendation.reason
            )
        }
    }
    
    struct ISFRecommendationCard: View {
        let recommendation: ISFRecommendation
        
        var body: some View {
            RecommendationCard(
                title: "💉 ISF (\(recommendation.timeBlock))",
                priority: recommendation.priority,
                currentValue: "\(recommendation.currentISF, specifier: "%.0f") mg/dL/U",
                recommendedValue: "\(recommendation.recommendedISF, specifier: "%.0f") mg/dL/U",
                change: "\(recommendation.changePercentage > 0 ? "+" : "")\(recommendation.changePercentage, specifier: "%.1f")%",
                reason: recommendation.reason
            )
        }
    }
    
    struct RecommendationCard: View {
        let title: String
        let priority: RecommendationPriority
        let currentValue: String
        let recommendedValue: String
        let change: String
        let reason: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    PriorityBadge(priority: priority)
                }
                
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(currentValue)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(recommendedValue)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(change)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(change.hasPrefix("+") ? .red : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (change.hasPrefix("+") ? Color.red : Color.green).opacity(0.1)
                        )
                        .cornerRadius(6)
                }
                
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(priorityColor(priority), lineWidth: 1)
            )
        }
        
        private func priorityColor(_ priority: RecommendationPriority) -> Color {
            switch priority {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .blue
            }
        }
    }
    
    struct PriorityBadge: View {
        let priority: RecommendationPriority
        
        var body: some View {
            Text(priority.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor)
                .cornerRadius(8)
        }
        
        private var priorityColor: Color {
            switch priority {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .blue
            }
        }
    }
    
    struct NoRecommendationsSection: View {
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("All Parameters Optimized!")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("No parameter adjustments recommended at this time. Your current settings appear to be working well!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGreen).opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
