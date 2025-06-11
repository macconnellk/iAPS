import SwiftUI
import Swinject

extension ParameterOptimization {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = ParameterOptimizationStateModel()
        
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
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear(perform: configureView)
            .navigationTitle("Parameter Optimization")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
