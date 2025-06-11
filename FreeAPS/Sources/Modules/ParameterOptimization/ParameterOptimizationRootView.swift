import SwiftUI
import Swinject

extension ParameterOptimization {
    struct RootView: BaseView {
        let resolver: Resolver
        
        var body: some View {
            Text("Parameter Optimization Works!")
                .navigationTitle("Parameter Optimization")
                .onAppear(perform: configureView)
        }
    }
}
