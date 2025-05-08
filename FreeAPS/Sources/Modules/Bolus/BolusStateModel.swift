import Foundation
import LoopKit
import SwiftUI
import Swinject

extension Bolus {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var unlockmanager: UnlockManager!
        @Injected() var apsManager: APSManager!
        @Injected() var broadcaster: Broadcaster!
        // added for bolus calculator
        @Injected() var settings: SettingsManager!
        @Injected() var announcementStorage: AnnouncementsStorage!
        @Injected() var carbsStorage: CarbsStorage!
        @Injected() var pumpHistoryStorage: PumpHistoryStorage!
        @Injected() var nsManager: NightscoutManager!

        @Published var suggestion: Suggestion?
        @Published var predictions: Predictions?
        @Published var amount: Decimal = 0
        @Published var insulinRecommended: Decimal = 0
        @Published var insulinRequired: Decimal = 0
        @Published var units: GlucoseUnits = .mmolL
        @Published var percentage: Decimal = 0
        @Published var threshold: Decimal = 0
        @Published var maxBolus: Decimal = 0
        @Published var maxCOB: Decimal = 0
        @Published var errorString: String = ""
        @Published var evBG: Decimal = 0
        @Published var insulin: Decimal = 0
        @Published var isf: Decimal = 0
        @Published var error: Bool = false
        @Published var minPredBG: Decimal = 0
        @Published var minDelta: Decimal = 0
        @Published var expectedDelta: Decimal = 0
        @Published var waitForSuggestion: Bool = false
        @Published var carbRatio: Decimal = 0

        var waitForSuggestionInitial: Bool = false
        @Published var waitForCarbs: Bool = false

        // added for bolus calculator
        @Published var recentGlucose: BloodGlucose?
        @Published var target: Decimal = 100
        @Published var cob: Decimal = 0
        @Published var iob: Decimal = 0

        @Published var currentBG: Decimal = 0
        @Published var manualGlucose: Decimal = 0
        @Published var fifteenMinInsulin: Decimal = 0
        @Published var deltaBG: Decimal = 0
        @Published var targetDifferenceInsulin: Decimal = 0
        @Published var wholeCobInsulin: Decimal = 0
        @Published var iobInsulinReduction: Decimal = 0
        @Published var wholeCalc: Decimal = 0
        @Published var roundedWholeCalc: Decimal = 0
        @Published var insulinCalculated: Decimal = 0
        @Published var deltaBasedInsulin: Decimal = 0
        @Published var predictionBasedInsulin: Decimal = 0
        @Published var roundedInsulinCalculated: Decimal = 0
        @Published var deltaReductionApplied: Bool = false
        @Published var predictionReductionApplied: Bool = false
        @Published var fraction: Decimal = 0
        @Published var useCalc: Bool = true
        @Published var fattyMeals: Bool = false
        @Published var fattyMealFactor: Decimal = 0
        @Published var useFattyMealCorrectionFactor: Bool = false
        @Published var displayPredictions: Bool = true
        
        // Added for enhanced calculation and logging
        @Published var latestCarbEntryInsulin: Decimal = 0
        @Published var roundedLatestCarbEntryInsulin: Decimal = 0
        @Published var log_roundedWholeCalc: Decimal = 0
        @Published var roundedwholeCalc_carbs: Decimal = 0
        @Published var log_roundedtargetDifferenceInsulin: Decimal = 0
        @Published var log_roundedwholeCobInsulin: Decimal = 0
        @Published var log_roundediobInsulinReduction: Decimal = 0
        @Published var wholeCalc_carbs: Decimal = 0
        @Published var carbInsulinFraction: Decimal = 0
        @Published var logMessage: String = ""
        @Published var viewlogMessage: String = "Waiting..."
        @Published var latestCarbValue: Decimal = 0
        @Published var manualCarbEntry: Decimal = 0
        @Published var log_manualCarbEntry_used: Decimal = 0
        @Published var latestCarbEntry: Decimal = 0
        @Published var belowThresholdInsulinReduction: Decimal = 0
        @Published var belowTargetInsulinReduction: Decimal = 0
        @Published var log_COBapproach: String = ""
        @Published var mostRecentCarbEntryTime: Date = .distantPast

        @Published var meal: [CarbsEntry]?
        @Published var carbs: Decimal = 0
        @Published var fat: Decimal = 0
        @Published var protein: Decimal = 0
        @Published var note: String = ""
        @Published var data = [InsulinRequired(agent: "Something", amount: 0)]
        @Published var bolusIncrement: Decimal = 0.1
        @Published var eventualBG: Bool = false
        @Published var minimumPrediction: Bool = false
        @Published var closedLoop: Bool = false
        @Published var loopDate: Date = .distantFuture
        @Published var now = Date.now
        @Published var bolus: Decimal = 0
        @Published var carbToStore = [CarbsEntry]()
        @Published var history: [PumpHistoryEvent]?

        let loopReminder: CGFloat = 4
        let coreDataStorage = CoreDataStorage()

        private var loopFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        private let processQueue = DispatchQueue(label: "setupBolusData.processQueue")

        override func subscribe() {
            setupInsulinRequired()
            broadcaster.register(SuggestionObserver.self, observer: self)
            units = settingsManager.settings.units
            minimumPrediction = settingsManager.settings.minumimPrediction
            threshold = settingsManager.preferences.threshold_setting
            maxBolus = provider.pumpSettings().maxBolus
            maxCOB = settings.preferences.maxCOB // Added to initialize maxCOB
            fraction = settings.settings.overrideFactor
            useCalc = settings.settings.useCalc
            fattyMeals = settings.settings.fattyMeals
            fattyMealFactor = settings.settings.fattyMealFactor
            eventualBG = settings.settings.eventualBG
            displayPredictions = settings.settings.displayPredictions
            bolusIncrement = settings.preferences.bolusIncrement
            closedLoop = settings.settings.closedLoop
            loopDate = apsManager.lastLoopDate

            if waitForSuggestionInitial {
                if waitForCarbs {
                    setupBolusData()
                } else {
                    apsManager.determineBasal()
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] ok in
                            guard let self = self else { return }
                            if !ok {
                                self.waitForSuggestion = false
                                self.insulinRequired = 0
                                self.insulinRecommended = 0
                            } else if let notNilSugguestion = provider.suggestion {
                                suggestion = notNilSugguestion
                                if let notNilPredictions = suggestion?.predictions {
                                    predictions = notNilPredictions
                                }
                            }
                        }.store(in: &lifetime)
                    setupPumpData()
                    loopDate = apsManager.lastLoopDate
                }
            }
            if let notNilSugguestion = provider.suggestion {
                suggestion = notNilSugguestion
                if let notNilPredictions = suggestion?.predictions {
                    predictions = notNilPredictions
                }
            }
        }

        func getDeltaBG() {
            let glucose = provider.fetchGlucose()
            guard let lastGlucose = glucose.first, glucose.count >= 4 else { return }
            deltaBG = Decimal(lastGlucose.glucose + glucose[1].glucose) / 2 -
                (Decimal(glucose[3].glucose + glucose[2].glucose) / 2)

            if currentBG == 0, (lastGlucose.date ?? .distantPast).timeIntervalSinceNow > -5.minutes.timeInterval {
                currentBG = Decimal(lastGlucose.glucose)
            }
        }
        
        // Get the most effective recent carbs value
        func getEffectiveRecentCarbs() -> Decimal {
            // If we have a manually specified entry from UI, use it
            if manualCarbEntry > 0 {
                return manualCarbEntry
            }
            
            // If we have carbs in carbToStore and they're recent (within last 120 seconds)
            if let carbEntry = carbToStore.first, 
               carbEntry.carbs > 0,
               let createdAt = carbEntry.createdAt,
               Date().timeIntervalSince(createdAt) < 120 {
                return carbEntry.carbs
            }
            
            // Otherwise use COB, but only if it seems valid
            if cob > 0 {
                return cob
            }
            
            // No valid carbs found
            return 0
        }

        func calculateInsulin() -> Decimal {
            let conversion: Decimal = units == .mmolL ? 0.0555 : 1
            
            // Get the most appropriate carb entry to use
            let effectiveCarbs = getEffectiveRecentCarbs()
            
            // The actual glucose threshold
            threshold = max(target - 0.5 * (target - 40 * conversion), threshold * conversion)

            // Use either the eventual glucose prediction or just the Swift code
            if eventualBG {
                if evBG > target {
                    // Use Oref0 predictions
                    insulin = (evBG - target) / isf
                } else { insulin = 0 }
            } else if currentBG == 0, manualGlucose > 0 {
                let targetDifference = manualGlucose * conversion - target
                // Leave insulin value at 0 when BG is at or below target
                if targetDifference > 0 {
                    targetDifferenceInsulin = isf == 0 ? 0 : targetDifference / isf
                } else {
                    targetDifferenceInsulin = 0
                }
            } else {
                let targetDifference = currentBG - target
                // Leave insulin value at 0 when BG is at or below target
                if targetDifference > 0 {
                    targetDifferenceInsulin = isf == 0 ? 0 : targetDifference / isf
                } else {
                    targetDifferenceInsulin = 0
                }
            }

            // more or less insulin because of bg trend in the last 15 minutes
            fifteenMinInsulin = isf == 0 ? 0 : (deltaBG * conversion) / isf

            // determine whole COB for which we want to dose insulin for and then determine insulin for wholeCOB
            // If failed recent suggestion use recent carb entry
            wholeCobInsulin = carbRatio != 0 ? max(cob, recentCarbs) / carbRatio : 0

            // determine user-defined fraction of insulin for latest carb entry. 
            if effectiveCarbs > 0 {
                
                // If COB is unexpectedly 0 but we have effectiveCarbs, use effectiveCarbs value up to maxCOB
                if cob == 0 {
                    wholeCobInsulin = carbRatio != 0 ? min(effectiveCarbs, maxCOB) / carbRatio : 0
                    // Turn off oref predictions blend bc not reliable without COB data
                    minimumPrediction = false
                }

                carbInsulinFraction = carbRatio != 0 ? effectiveCarbs / carbRatio : 0
                if effectiveCarbs > maxCOB {
                    carbInsulinFraction = carbInsulinFraction * fraction
                }
            }

            // Log the Max Approach
            if wholeCobInsulin >= carbInsulinFraction {
                log_COBapproach = "COB Insulin Used"
            } else {
                log_COBapproach = "Fraction Carb Insulin Used"
            }

            // Set Approach Reccomendation to the higher amount. Ensures more insulin dosed up front for high carb meals
            wholeCobInsulin = max(wholeCobInsulin, carbInsulinFraction)

            // determine how much the calculator reduces/ increases the bolus because of IOB
            // If failed recent suggestion use recent IOB value
            if iob > 0 {
                iobInsulinReduction = (-1) * max(iob, recentIOB)
            } else {
                iobInsulinReduction = (-1) * max(iob, recentIOB)
            }

            // adding everything together
            // add a calc for the case that no fifteenMinInsulin is available
            if deltaBG != 0 {
                wholeCalc = (targetDifferenceInsulin + iobInsulinReduction + wholeCobInsulin + fifteenMinInsulin)
            } else if currentBG == 0, manualGlucose == 0 {
                // add (rare) case that no glucose value is available -> maybe display warning?
                // if no bg is available, ?? sets its value to 0
                wholeCalc = (iobInsulinReduction + wholeCobInsulin)
            } else {
                wholeCalc = (targetDifferenceInsulin + iobInsulinReduction + wholeCobInsulin)
            }
            
            // Basic log setup - will enhance in next layer
            logMessage = "CR: \(carbRatio). \nCOB Approach: \(cob) "

            // apply custom factor at the end of the calculations
            // New code moving fraction up to the COB/Carb calculation
            let result = !eventualBG ? wholeCalc : insulin * fraction
            
            // apply custom factor if fatty meal toggle in bolus calc config settings is on and the box for fatty meals is checked (in RootView)
            if useFattyMealCorrectionFactor {
                insulinCalculated = result * fattyMealFactor
            } else {
                insulinCalculated = result
            }

            // Account for increments (Don't use the apsManager function as that gets much too slow)
            insulinCalculated = roundBolus(insulinCalculated)
            // 0 up to maxBolus
            insulinCalculated = min(max(insulinCalculated, 0), maxBolus)

            prepareData()

            return insulinCalculated
        }

        /// When COB module fail
        var recentCarbs: Decimal {
            var temporaryCarbs: Decimal = 0
            guard let temporary = carbToStore.first else { return 0 }
            let timeDifference = (temporary.actualDate ?? .distantPast).timeIntervalSinceNow
            if timeDifference <= 0, timeDifference > -15.minutes.timeInterval {
                temporaryCarbs = temporary.carbs
            }
            return temporaryCarbs
        }

        /// When IOB module fail
        var recentIOB: Decimal {
            guard iob == 0 else { return 0 }
            guard let recent = coreDataStorage.recentReason() else { return 0 }
            let timeDifference = (recent.date ?? .distantPast).timeIntervalSinceNow
            if timeDifference <= 0, timeDifference > -30.minutes.timeInterval {
                return ((recent.iob ?? 0) as Decimal)
            } else if let history = history {
                let total = history
                    .filter({ $0.timestamp.timeIntervalSinceNow > -90.minutes.timeInterval && $0.type == .bolus })
                    .compactMap(\.amount).reduce(0, +)
                return max(total, 0)
            }
            return 0
        }

        func setupPumpData() {
            DispatchQueue.main.async {
                self.history = self.provider.pumpHistory()
            }
        }

        func add() {
            guard amount > 0 else {
                showModal(for: nil)
                return
            }

            let maxAmount = Double(min(amount, provider.pumpSettings().maxBolus))

            unlockmanager.unlock()
                .sink { _ in } receiveValue: { [weak self] _ in
                    guard let self = self else { return }
                    self.save()
                    self.apsManager.enactBolus(amount: maxAmount, isSMB: false)
                    self.showModal(for: nil)
                }
                .store(in: &lifetime)
        }

        func save() {
            guard !empty else { return }
            carbsStorage.storeCarbs(carbToStore)
        }

        func setupInsulinRequired() {
            let conversion: Decimal = units == .mmolL ? 0.0555 : 1
            DispatchQueue.main.async {
                if let suggestion = self.provider.suggestion {
                    self.insulinRequired = suggestion.insulinReq ?? 0
                    self.evBG = Decimal(suggestion.eventualBG ?? 0) * conversion
                    self.iob = suggestion.iob ?? 0
                    self.currentBG = (suggestion.bg ?? 0) * conversion
                    self.cob = suggestion.cob ?? 0
                }
                // Unwrap. We can't have NaN values.
                if let reasons = CoreDataStorage().fetchReason(), let target = reasons.target, let isf = reasons.isf,
                   let carbRatio = reasons.cr, let minPredBG = reasons.minPredBG
                {
                    self.target = target as Decimal
                    self.isf = isf as Decimal
                    self.carbRatio = carbRatio as Decimal
                    self.minPredBG = minPredBG as Decimal
                }

                if self.useCalc {
                    self.getDeltaBG()
                    self.insulinCalculated = self.calculateInsulin()
                    self.prepareData()
                }
            }
        }

        func backToCarbsView(override: Bool, editMode: Bool) {
            showModal(for: .addCarbs(editMode: editMode, override: override))
        }

        func carbsView(fetch: Bool, hasFatOrProtein: Bool, mealSummary: FetchedResults<Meals>) -> Bool {
            var keepForNextWiew = false
            if fetch {
                keepForNextWiew = true
                backToCarbsView(override: false, editMode: true)
            } else {
                backToCarbsView(override: true, editMode: false)
            }
            return keepForNextWiew
        }

        func remoteBolus() -> String? {
            if let enactedAnnouncement = announcementStorage.recentEnacted() {
                let components = enactedAnnouncement.notes.split(separator: ":")
                guard components.count == 2 else { return nil }
                let command = String(components[0]).lowercased()
                let eventual: String = units == .mmolL ? evBG.asMmolL
                    .formatted(.number.grouping(.never).rounded().precision(.fractionLength(1))) : evBG.formatted()

                if command == "bolus" {
                    return "\n" + NSLocalizedString("A Remote Bolus ", comment: "Remote Bolus Alert, part 1") +
                        NSLocalizedString("was delivered", comment: "Remote Bolus Alert, part 2") + (
                            -1 * enactedAnnouncement.createdAt
                                .timeIntervalSinceNow
                                .minutes
                        )
                        .formatted(.number.grouping(.never).rounded().precision(.fractionLength(0))) +
                        NSLocalizedString(
                            " minutes ago, triggered remotely from Nightscout, by a caregiver or a parent. Do you still want to bolus?\n\nPredicted eventual glucose, if you don't bolus, is: ",
                            comment: "Remote Bolus Alert, part 3"
                        ) + eventual + " " + units.rawValue
                }
            }
            return nil
        }

        func notActive() {
            let defaults = UserDefaults.standard
            defaults.set(false, forKey: IAPSconfig.inBolusView)
            // print("Active: NO") // For testing
        }

        func viewActive() {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: IAPSconfig.inBolusView)
            // print("Active: YES") // For testing
        }

        var conversion: Decimal {
            units == .mmolL ? 0.0555 : 1
        }

        private func prepareData() {
            if !eventualBG {
                var prepareData = [
                    InsulinRequired(agent: NSLocalizedString("Carbs", comment: ""), amount: wholeCobInsulin),
                    InsulinRequired(agent: NSLocalizedString("IOB", comment: ""), amount: iobInsulinReduction),
                    InsulinRequired(agent: NSLocalizedString("Glucose", comment: ""), amount: targetDifferenceInsulin),
                    InsulinRequired(agent: NSLocalizedString("Trend", comment: ""), amount: fifteenMinInsulin),
                    InsulinRequired(agent: NSLocalizedString("Factors", comment: ""), amount: 0),
                    InsulinRequired(agent: NSLocalizedString("Amount", comment: ""), amount: insulinCalculated)
                ]
                let total = prepareData.dropLast().map(\.amount).reduce(0, +)
                if total > 0 {
                    let factor = -1 * (total - insulinCalculated)
                    prepareData[4].amount = abs(factor) >= bolusIncrement ? factor : 0
                }
                data = prepareData
            }
        }

        func lastLoop() -> String? {
            guard closedLoop else { return nil }
            guard abs(now.timeIntervalSinceNow / 60) > loopReminder else { return nil }
            let minAgo = abs(loopDate.timeIntervalSinceNow / 60)

            let stringAgo = loopFormatter.string(from: minAgo as NSNumber) ?? ""
            return "Last loop \(stringAgo) minutes ago. Complete or cancel this meal/bolus transaction to allow for next loop cycle to run"
        }

        private func roundBolus(_ amount: Decimal) -> Decimal {
            // Account for increments (don't use the APSManager function as that gets too slow)
            Decimal(round(Double(amount / bolusIncrement))) * bolusIncrement
        }

        func setupBolusData() {
            if let recent = coreDataStorage.recentMeal() {
                // Store the carbs value for use in calculations
                manualCarbEntry = Decimal(recent.carbs)
                mostRecentCarbEntryTime = recent.createdAt ?? Date.now
                
                carbToStore = [CarbsEntry(
                    id: recent.id,
                    createdAt: (recent.createdAt ?? Date.now).addingTimeInterval(5.seconds.timeInterval),
                    actualDate: recent.actualDate,
                    carbs: Decimal(recent.carbs),
                    fat: Decimal(recent.fat),
                    protein: Decimal(recent.protein),
                    note: recent.note,
                    enteredBy: CarbsEntry.manual,
                    isFPU: false
                )]

                if let passForward = carbToStore.first {
                    apsManager.temporaryData = TemporaryData(forBolusView: passForward)
                    apsManager.determineBasal()
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] ok in
                            guard let self = self else { return }
                            if !ok {
                                self.waitForSuggestion = false
                                self.waitForCarbs = false
                                self.insulinRequired = 0
                                self.insulinRecommended = 0
                            } else if let notNilSugguestion = provider.suggestion {
                                suggestion = notNilSugguestion
                                if let notNilPredictions = suggestion?.predictions {
                                    predictions = notNilPredictions
                                }
                            }
                        }.store(in: &lifetime)
                    setupPumpData()
                    loopDate = apsManager.lastLoopDate
                }
            }
        }

        private var empty: Bool {
            (carbToStore.first?.carbs ?? 0) == 0 && (carbToStore.first?.fat ?? 0) == 0 && (carbToStore.first?.protein ?? 0) == 0
        }
    }
}

extension Bolus.StateModel: SuggestionObserver {
    func suggestionDidUpdate(_: Suggestion) {
        DispatchQueue.main.async {
            self.waitForSuggestion = false
        }
        setupInsulinRequired()
        loopDate = apsManager.lastLoopDate

        if abs(now.timeIntervalSinceNow / 60) > loopReminder * 1.5 {
            hideModal()
            notActive()
            debug(.apsManager, "Force Closing Bolus View", printToConsole: true)
        }
    }
}

extension Decimal {
    /// Account for increments
    func roundBolus(increment: Double) -> Decimal {
        Decimal(round(Double(self) / increment)) * Decimal(increment)
    }
}
