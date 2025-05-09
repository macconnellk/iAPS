import Charts
import CoreData
import SwiftUI
import Swinject

extension Bolus {
    struct AlternativeBolusCalcRootView: BaseView {
        let resolver: Resolver
        let waitForSuggestion: Bool
        let fetch: Bool
        @StateObject var state: StateModel
        @State private var showInfo = false
        @State private var exceededMaxBolus = false
        @State private var keepForNextWiew: Bool = false
        @State private var remoteBolusAlert: Alert?
        @State private var isRemoteBolusAlertPresented: Bool = false

        private enum Config {
            static let dividerHeight: CGFloat = 2
            static let overlayColour: Color = .white // Currently commented out
            static let spacing: CGFloat = 3
        }

        @Environment(\.colorScheme) var colorScheme
        @FocusState private var isFocused: Bool

        let meal: FetchedResults<Meals>
        let mealEntries: any View

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var mealFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var gluoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            } else { formatter.maximumFractionDigits = 0 }
            return formatter
        }

        private var fractionDigits: Int {
            if state.units == .mmolL {
                return 1
            } else { return 0 }
        }

        var body: some View {
            Form {
                Section {
                    if state.waitForSuggestion {
                        Text("Please wait")
                    } else if state.predictions != nil {
                        predictionChart
                    } else {
                        Text("No Predictions. Failed loop suggestion.").frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                if state.predictions == nil {
                    if state.currentBG == 0 {
                        Section {
                            HStack {
                                Text("Glucose")
                                Spacer()
                                BGTextField(
                                    "0",
                                    mgdlValue: $state.manualGlucose,
                                    units: $state.units,
                                    isDisabled: false,
                                    liveEditing: true
                                )
                            }.onChange(of: state.manualGlucose) {
                                state.insulinCalculated = state.calculateInsulin()
                            }
                        } header: { Text("Missing Glucose") }
                    }
                }

                Section {}
                if fetch {
                    Section { mealEntries.asAny() }
                }

                Section {
                    if !state.waitForSuggestion {
                        HStack {
                            Button(action: {
                                showInfo.toggle()
                            }, label: {
                                Image(systemName: "info.bubble")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(colorScheme == .light ? .black : .white, .blue)
                                    .font(.infoSymbolFont)
                                Text("Calculations")
                            })
                                .foregroundStyle(.blue)
                                .font(.footnote)
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if state.fattyMeals {
                                Spacer()
                                Toggle(isOn: $state.useFattyMealCorrectionFactor) {
                                    Text("Fatty Meal")
                                }
                                .toggleStyle(CheckboxToggleStyle())
                                .font(.footnote)
                                .onChange(of: state.useFattyMealCorrectionFactor) {
                                    state.insulinCalculated = state.calculateInsulin()
                                }
                            }
                        }
                    }

                    if state.waitForSuggestion {
                        HStack {
                            Text("Wait please").foregroundColor(.secondary)
                            Spacer()
                            ActivityIndicator(isAnimating: .constant(true), style: .medium) // fix iOS 15 bug
                        }
                    } else {
                        HStack {
                            Text("Insulin recommended")
                            Spacer()
                            Text(
                                formatter
                                    .string(from: Double(state.insulinCalculated) as NSNumber) ?? ""
                            )
                            Text(
                                NSLocalizedString(" U", comment: "Unit in number of units delivered (keep the space character!)")
                            ).foregroundColor(.secondary)
                        }.contentShape(Rectangle())
                            .onTapGesture { state.amount = state.insulinCalculated }
                    }

                    HStack {
                        Text("Bolus")
                        Spacer()
                        DecimalTextField(
                            "0",
                            value: $state.amount,
                            formatter: formatter,
                            liveEditing: true
                        )
                        Text(exceededMaxBolus ? "😵" : " U").foregroundColor(.secondary)
                    }
                    .focused($isFocused)
                    .onChange(of: state.amount) {
                        if state.amount > state.maxBolus {
                            exceededMaxBolus = true
                        } else {
                            exceededMaxBolus = false
                        }
                    }
                }

                if state.amount > 0 {
                    Section {
                        Button {
                            if let remoteBolus = state.remoteBolus() {
                                remoteBolusAlert = Alert(
                                    title: Text("A Remote Bolus Was Just Delivered!"),
                                    message: Text(remoteBolus),
                                    primaryButton: .destructive(Text("Bolus"), action: {
                                        keepForNextWiew = true
                                        state.add()
                                    }),
                                    secondaryButton: .cancel()
                                )
                                isRemoteBolusAlertPresented = true
                            } else {
                                keepForNextWiew = true
                                state.add()
                            }
                        }
                        label: { Text(exceededMaxBolus ? "Max Bolus exceeded!" : "Enact bolus") }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .disabled(disabled)
                            .listRowBackground(!disabled ? Color(.systemBlue) : Color(.systemGray4))
                            .tint(.white)
                    }
                    footer: {
                        if (-1 * state.loopDate.timeIntervalSinceNow / 60) > state.loopReminder, let string = state.lastLoop() {
                            Text(NSLocalizedString(string, comment: "Bolus View footer"))
                                .padding(.top, 20).multilineTextAlignment(.center)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if state.amount <= 0 {
    Section {
        Button {
            keepForNextWiew = true
            state.save()
            state.showModal(for: nil)
        }
        label: {
            fetch ?
                Text("Save Meal without bolus") :
                Text("Continue without bolus")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color(.systemBlue))
        .tint(.white)
        
        // Add this new enhanced calculation log display
        VStack(alignment: .leading, spacing: 4) {
            DisclosureGroup(
                content: {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            // Basic parameters
                            Group {
                                HStack {
                                    Text("Carb Ratio:").bold()
                                    Spacer()
                                    Text("\(state.carbRatio, specifier: "%.1f")")
                                }
                                
                                HStack {
                                    Text("ISF:").bold()
                                    Spacer()
                                    Text("\(state.isf, specifier: "%.1f") \(state.units.rawValue)/U")
                                }
                                
                                HStack {
                                    Text("Current BG:").bold()
                                    Spacer()
                                    Text("\(state.currentBG, specifier: "%.1f") \(state.units.rawValue)")
                                }
                                
                                HStack {
                                    Text("Target:").bold()
                                    Spacer()
                                    Text("\(state.target, specifier: "%.1f") \(state.units.rawValue)")
                                }
                            }
                            
                            Divider()
                            
                            // Insulin components
                            Group {
                                if state.log_manualCarbEntry_used > 0 {
                                    HStack {
                                        Text("Carbs Used:").bold()
                                        Spacer()
                                        Text("\(state.log_manualCarbEntry_used, specifier: "%.1f") g → \(state.roundedLatestCarbEntryInsulin, specifier: "%.2f") U")
                                            .foregroundStyle(Color(.loopYellow))
                                    }
                                }
                                
                                HStack {
                                    Text("COB:").bold()
                                    Spacer()
                                    Text("\(state.cob, specifier: "%.1f") g → \(state.log_roundedwholeCobInsulin, specifier: "%.2f") U")
                                        .foregroundStyle(Color(.loopYellow))
                                }
                                
                                if state.log_roundedtargetDifferenceInsulin != 0 {
                                    HStack {
                                        Text("BG Correction:").bold()
                                        Spacer()
                                        Text("\(state.log_roundedtargetDifferenceInsulin, specifier: "%.2f") U")
                                            .foregroundStyle(Color(.loopGreen))
                                    }
                                }
                                
                                if state.iobInsulinReduction != 0 {
                                    HStack {
                                        Text("IOB:").bold()
                                        Spacer()
                                        Text("\(state.log_roundediobInsulinReduction, specifier: "%.2f") U")
                                            .foregroundStyle(Color(.insulin))
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Safety adjustments
                            if state.deltaReductionApplied || state.predictionReductionApplied {
                                Group {
                                    Text("Safety Adjustments:").bold()
                                    
                                    if state.deltaReductionApplied {
                                        HStack {
                                            Text("• BG Dropping:")
                                            Spacer()
                                            Text("\(state.deltaBG, specifier: "%.1f") mg/dL/5min")
                                                .foregroundStyle(.orange)
                                        }
                                        .padding(.leading, 8)
                                    }
                                    
                                    if state.predictionReductionApplied {
                                        HStack {
                                            Text("• Low BG Predicted:")
                                            Spacer()
                                            Text("\(state.minPredBG, specifier: "%.1f") \(state.units.rawValue)")
                                                .foregroundStyle(.orange)
                                        }
                                        .padding(.leading, 8)
                                    }
                                }
                                
                                Divider()
                            }
                            
                            // Final calculation
                            HStack {
                                Text("Final Calculation:").bold()
                                Spacer()
                                Text("\(state.insulinCalculated, specifier: "%.2f") U")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 300)
                },
                label: {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Calculation Details")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                }
            )
            .accentColor(.blue)
        }
        .padding(.vertical, 4)
    }
    footer: {
        if (-1 * state.loopDate.timeIntervalSinceNow / 60) > state.loopReminder, let string = state.lastLoop() {
            Text(NSLocalizedString(string, comment: "Bolus View footer"))
                .padding(.top, 20).multilineTextAlignment(.center)
                .foregroundStyle(.orange)
        }
    }
}
            }
            .interactiveDismissDisabled()
            .compactSectionSpacing()
            .alert(isPresented: $isRemoteBolusAlertPresented) {
                remoteBolusAlert!
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .navigationTitle("Enact Bolus")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button {
                    keepForNextWiew = state.carbsView(fetch: fetch, hasFatOrProtein: hasFatOrProtein, mealSummary: meal)
                }
                label: {
                    HStack {
                        Image(systemName: "chevron.backward")
                        Text("Meal")
                    }
                },
                trailing: Button {
                    state.hideModal()
                    state.notActive()
                    if fetch { state.apsManager.determineBasalSync() }
                }
                label: { Text("Cancel") }
            )
            .onAppear {
                configureView {
                    state.viewActive()
                    state.waitForCarbs = fetch
                    state.waitForSuggestionInitial = waitForSuggestion
                    state.waitForSuggestion = waitForSuggestion
                    // Added by Claude
                    if let carbs = meal.first?.carbs, carbs > 0 {
                        state.manualCarbEntry = Decimal(carbs)
                    }
                    state.insulinCalculated = state.calculateInsulin()
                }
            }
            .popup(isPresented: showInfo, alignment: .bottom, direction: .center, type: .default) {
                illustrationView()
            }
        }

        var predictionChart: some View {
            ZStack {
                PredictionView(
                    predictions: $state.predictions, units: $state.units, eventualBG: $state.evBG,
                    useEventualBG: $state.eventualBG, target: $state.target,
                    displayPredictions: $state.displayPredictions, currentGlucose: $state.currentBG
                )
            }
        }

        private var disabled: Bool {
            state.amount <= 0 || state.amount > state.maxBolus
        }

        var changed: Bool {
            ((meal.first?.carbs ?? 0) > 0) || ((meal.first?.fat ?? 0) > 0) || ((meal.first?.protein ?? 0) > 0)
        }

        var hasFatOrProtein: Bool {
            ((meal.first?.fat ?? 0) > 0) || ((meal.first?.protein ?? 0) > 0)
        }

        func carbsView() {
            if fetch {
                keepForNextWiew = true
                state.backToCarbsView(override: false, editMode: true)
            } else {
                state.backToCarbsView(override: true, editMode: false)
            }
        }

        private func illustrationView() -> some View {
            VStack {
                IllustrationView(data: $state.data)

                // Hide button
                VStack {
                    Button { showInfo = false }
                    label: { Text("Hide") }.frame(maxWidth: .infinity, alignment: .center)
                        .tint(.blue)
                }.padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(colorScheme == .dark ? UIColor.systemGray4 : UIColor.systemGray5))
            )
        }
    }
}
