Section {
    Text("OpenAPS").navigationLink(to: .preferencesEditor, from: self)
    Text("Autotune").navigationLink(to: .autotuneConfig, from: self)
    NavigationLink("Parameter Optimization") {
        Text("Parameter Optimization Works!")
            .navigationTitle("Parameter Optimization")
    }
} header: { Text("OpenAPS") }
