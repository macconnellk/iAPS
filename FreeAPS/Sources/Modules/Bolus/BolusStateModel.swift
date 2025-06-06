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

        @Published var suggestion: Suggestion?
        @Published var predictions: Predictions?
        @Published var amount: Decimal = 0
        @Published var insulinRecommended: Decimal = 0
        @Published var insulinRequired: Decimal = 0
        @Published var units: GlucoseUnits = .mmolL
        @Published var percentage: Decimal = 0
        @Published var threshold: Decimal = 0
        @Published var maxBolus: Decimal = 0
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
        @Published var insulinCalculated: Decimal = 0
        @Published var roundedInsulinCalculated: Decimal = 0
        @Published var fraction: Decimal = 0
        @Published var useCalc: Bool = true
        @Published var fattyMeals: Bool = false
        @Published var fattyMealFactor: Decimal = 0
        @Published var useFattyMealCorrectionFactor: Bool = false
        @Published var displayPredictions: Bool = true

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

        // YOUR ENHANCED LOGGING PROPERTIES
        @Published var maxCOB: Decimal = 0
        @Published var roundedWholeCalc: Decimal = 0
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
        @Published var manualCarbEntry: Decimal = 0
        @Published var log_manualCarbEntry_used: Decimal = 0
        @Published var belowThresholdInsulinReduction: Decimal = 0
        @Published var belowTargetInsulinReduction: Decimal = 0
        @Published var log_COBapproach: String = ""
        @Published var deltaBasedInsulin: Decimal = 0
        @Published var predictionBasedInsulin: Decimal = 0
        @Published var deltaReductionApplied: Bool = false
        @Published var predictionReductionApplied: Bool = false
        @Published var mostRecentCarbEntryTime: Date = .distantPast
        @Published var historicalCarbs: [CarbsEntry] = []
        

        //Your enhanced Large Meal settings
        // Add these new properties to your existing @Published variables section:
        @Published var enableLargeMealMode: Bool = UserDefaults.standard.bool(forKey: "largeMealMode") {
            didSet { UserDefaults.standard.set(enableLargeMealMode, forKey: "largeMealMode") }
            }

        @Published var largeMealTimeWindow: Double = UserDefaults.standard.double(forKey: "largeMealTimeWindow") != 0 ? 
            UserDefaults.standard.double(forKey: "largeMealTimeWindow") : 60 {
            didSet { UserDefaults.standard.set(largeMealTimeWindow, forKey: "largeMealTimeWindow") }
            }

        @Published var largeMealThreshold: Double = UserDefaults.standard.double(forKey: "largeMealThreshold") != 0 ? 
            UserDefaults.standard.double(forKey: "largeMealThreshold") : 65 {
            didSet { UserDefaults.standard.set(largeMealThreshold, forKey: "largeMealThreshold") }
        }

        @Published var carbAbsorptionRate: Double = UserDefaults.standard.double(forKey: "carbAbsorptionRate") != 0 ? 
            UserDefaults.standard.double(forKey: "carbAbsorptionRate") : 30 {
            didSet { UserDefaults.standard.set(carbAbsorptionRate, forKey: "carbAbsorptionRate") }
            }

        @Published var largeMealFraction: Double = UserDefaults.standard.double(forKey: "largeMealFraction") != 0 ? 
            UserDefaults.standard.double(forKey: "largeMealFraction") : 0.8 {
            didSet { UserDefaults.standard.set(largeMealFraction, forKey: "largeMealFraction") }
            }

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
            broadcaster.register(SuggestionObserver.self, observer: self)
            units = settingsManager.settings.units
            minimumPrediction = settingsManager.settings.minumimPrediction
            threshold = settingsManager.preferences.threshold_setting
            maxBolus = provider.pumpSettings().maxBolus
            // YOUR ADDITION: maxCOB setting
            maxCOB = settings.preferences.maxCOB
            fraction = settings.settings.overrideFactor
            useCalc = settings.settings.useCalc
            fattyMeals = settings.settings.fattyMeals
            fattyMealFactor = settings.settings.fattyMealFactor
            eventualBG = settings.settings.eventualBG
            displayPredictions = settings.settings.displayPredictions
            bolusIncrement = settings.preferences.bolusIncrement
            closedLoop = settings.settings.closedLoop
            loopDate = apsManager.lastLoopDate

            //Load historical carbs data like DataTable does
            loadHistoricalCarbs()

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
            setupInsulinRequired()
        }

        // Added function to load historical carbs
        private func loadHistoricalCarbs() {
            let processQueue = DispatchQueue(label: "loadHistoricalCarbs.processQueue")
    
            processQueue.async {
                do {
                    // Load carbs data (same call as DataTable)
                    let carbs = self.carbsStorage.recent()
                        .filter { !($0.isFPU ?? false) } // Same filter as DataTable
            
                    DispatchQueue.main.async {
                        self.historicalCarbs = carbs
                        print("Loaded \(carbs.count) historical carbs at startup")
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Error loading historical carbs: \(error)")
                        self.historicalCarbs = []
                    }
                }
           }
        }

        
        
        func getDeltaBG() {
            let glucose = provider.fetchGlucose()
            guard let lastGlucose = glucose.first, glucose.count >= 4 else { return }
            guard (lastGlucose.date ?? .distantPast).timeIntervalSinceNow > -7.minutes.timeInterval else {
                currentBG = 0
                return
            }
            deltaBG = Decimal(lastGlucose.glucose + glucose[1].glucose) / 2 -
                (Decimal(glucose[3].glucose + glucose[2].glucose) / 2)
            
            // YOUR ADDITION: Set currentBG if it's 0 and glucose is recent
            if currentBG == 0, (lastGlucose.date ?? .distantPast).timeIntervalSinceNow > -5.minutes.timeInterval {
                currentBG = Decimal(lastGlucose.glucose)
            }
        }

        // YOUR ADDITION: Rounding helper function
        func roundToHundredth(_ value: Decimal) -> Decimal {
            var result = value
            var roundedValue = Decimal()

            NSDecimalRound(&roundedValue, &result, 2, .plain)
            return roundedValue
        }

        // Custom Addition
        func getEffectiveRecentCarbs() -> Decimal {
            if let currentCarb = carbToStore.first, currentCarb.carbs > 0 {
                mostRecentCarbEntryTime = currentCarb.actualDate ?? currentCarb.createdAt ?? Date()
                return currentCarb.carbs
            }
    
            let now = Date()
            if manualCarbEntry > 0 && abs(now.timeIntervalSince(mostRecentCarbEntryTime)) < 300 {
                return manualCarbEntry
            }
    
            return 0
        }

    // COMPLETE calculateTieredInsulin function (the new shared function)
    func calculateTieredInsulin(totalCarbs: Decimal, includeCorrections: Bool = true, logPrefix: String = "") -> Decimal {
    guard totalCarbs > 0 else { return 0 }
    
    let largeMealThresholdDecimal = Decimal(largeMealThreshold)
    
    // Determine if tiered dosing applies
    let useTieredDosing = totalCarbs > largeMealThresholdDecimal
    
    var carbInsulin: Decimal = 0
    
    if useTieredDosing {
        // TIERED DOSING: 100% for first portion + fraction for additional
        let baseCarbs = min(totalCarbs, largeMealThresholdDecimal)  // First portion at threshold
        let additionalCarbs = max(0, totalCarbs - largeMealThresholdDecimal)  // Above threshold
        
        let baseInsulin = baseCarbs / carbRatio  // 100% dosing for first portion
        let additionalInsulin = (additionalCarbs / carbRatio) * Decimal(largeMealFraction)  // Fraction for excess
        carbInsulin = baseInsulin + additionalInsulin
        
        logMessage += "\n\(logPrefix)TIERED DOSING APPLIED:"
        logMessage += "\n\(logPrefix)• Total carbs: \(roundToHundredth(totalCarbs))g"
        logMessage += "\n\(logPrefix)• First \(roundToHundredth(baseCarbs))g at 100%: \(roundToHundredth(baseInsulin))U"
        logMessage += "\n\(logPrefix)• Additional \(roundToHundredth(additionalCarbs))g at \(Int(largeMealFraction * 100))%: \(roundToHundredth(additionalInsulin))U"
        logMessage += "\n\(logPrefix)• Total carb insulin: \(roundToHundredth(carbInsulin))U"
    } else {
        // STANDARD DOSING: 100% for all carbs
        carbInsulin = totalCarbs / carbRatio
        
        logMessage += "\n\(logPrefix)STANDARD DOSING:"
        logMessage += "\n\(logPrefix)• Total carbs: \(roundToHundredth(totalCarbs))g (≤ \(largeMealThresholdDecimal)g threshold)"
        logMessage += "\n\(logPrefix)• Carb insulin at 100%: \(roundToHundredth(carbInsulin))U"
    }
    
    var totalInsulin = carbInsulin
    
    // Add BG correction if requested
    if includeCorrections {
        totalInsulin += targetDifferenceInsulin
        logMessage += "\n\(logPrefix)• BG correction: \(roundToHundredth(targetDifferenceInsulin))U"
        logMessage += "\n\(logPrefix)• Total before IOB: \(roundToHundredth(totalInsulin))U"
        
        // Apply IOB reduction
        let iobReduction = iob > 0 ? iob : 0
        totalInsulin = max(0, totalInsulin - iobReduction)
        logMessage += "\n\(logPrefix)• IOB reduction: \(roundToHundredth(iobReduction))U"
        logMessage += "\n\(logPrefix)• Total after IOB: \(roundToHundredth(totalInsulin))U"
    }
    
    // Apply safety cap
    let safetyMaxInsulin: Decimal = min(6.0, maxBolus * 0.8)
    let cappedInsulin = min(totalInsulin, safetyMaxInsulin)
    
    if cappedInsulin != totalInsulin {
        logMessage += "\n\(logPrefix)• Safety cap applied: \(roundToHundredth(cappedInsulin))U"
    }
    
    // Apply safety reductions
    let finalInsulin = applySafetyReductions(rawInsulin: cappedInsulin, isLargeMeal: useTieredDosing)
    
    logMessage += "\n\(logPrefix)• Final after safety: \(roundToHundredth(finalInsulin))U"
    
    return finalInsulin
}
        
        // EXTRACTED: Safety reduction logic that both main calculation and large meal can use
        func applySafetyReductions(rawInsulin: Decimal, isLargeMeal: Bool = false) -> Decimal {
            var deltaBasedInsulin = rawInsulin
            var predictionBasedInsulin = rawInsulin
            let originalInsulin = rawInsulin
    
            // Calculate BG delta-based reduction
            if deltaBasedInsulin > 0 {
                if deltaBG <= -45 && currentBG < (threshold + 50) {
                    // Double arrow down rate (>3 mg/dL/min drop)
                    deltaBasedInsulin = deltaBasedInsulin * 0.7
                    deltaReductionApplied = true
                    logMessage += "\nVery rapid BG drop \(deltaBG), delta-based calculation suggests 70% of original bolus"
                } else if deltaBG <= -30 && currentBG < (threshold + 30) {
            // Single arrow down rate (2-3 mg/dL/min drop)
            deltaBasedInsulin = deltaBasedInsulin * 0.8
            deltaReductionApplied = true
            logMessage += "\nRapid BG drop \(deltaBG), delta-based calculation suggests 80% of original bolus"
               }
            }
    
            // Calculate prediction-based reduction
            if minimumPrediction && predictionBasedInsulin > 0 {
                if minPredBG < threshold {
                    // Reduce insulin based on threshold prediction
                    belowThresholdInsulinReduction = roundBolus(abs(threshold + 10 - minPredBG) / isf)
                    // Apply a safety factor to reduce further
                    belowThresholdInsulinReduction = roundBolus(belowThresholdInsulinReduction * 1.25)
                    predictionBasedInsulin = predictionBasedInsulin - abs(belowThresholdInsulinReduction)
                    predictionReductionApplied = true
                    logMessage += "\nminPrediction \(minPredBG) < threshold, prediction-based calculation suggests reducing bolus by \(belowThresholdInsulinReduction)"
                } else if evBG < target {
                    // Reduce insulin based on eventual BG prediction
                    belowTargetInsulinReduction = roundBolus(abs(target - evBG) / isf)
                    predictionBasedInsulin = predictionBasedInsulin - abs(belowTargetInsulinReduction)
                    predictionReductionApplied = true
                    logMessage += "\nEventual BG \(evBG) < target, prediction-based calculation suggests reducing bolus by \(belowTargetInsulinReduction)"
                }
            }
    
            // Choose the minimum insulin amount
            let finalInsulin = min(deltaBasedInsulin, predictionBasedInsulin)
    
            // Add comparison log if both reductions applied
            if deltaReductionApplied && predictionReductionApplied {
                logMessage += "\nFinal insulin calculation chose minimum between delta-based (\(roundToHundredth(deltaBasedInsulin))) and prediction-based (\(roundToHundredth(predictionBasedInsulin))) calculations"
            }
    
            // Only add final insulin amount if any safety reductions were applied
            if deltaReductionApplied || predictionReductionApplied {
                if finalInsulin != originalInsulin {
                    let mealType = isLargeMeal ? "large meal" : "standard"
                    logMessage += "\nFinal \(mealType) insulin after safety: \(roundToHundredth(finalInsulin))U"
                }
            }
    
            return finalInsulin
        }
      
   // COMPLETE checkForMultipleCarbEntries function
    func checkForMultipleCarbEntries(currentCalculatedInsulin: Decimal) -> Decimal {
    // Check if large meal mode is enabled
    guard enableLargeMealMode else { return 0 }
    
    let currentTime = Date()
    let timeWindowSeconds = largeMealTimeWindow * 60
    let cutoffTime = currentTime.addingTimeInterval(-timeWindowSeconds)
    
    // Get both data sources for comparison
    let coreDataMeals = coreDataStorage.fetchRecentMeals(within: timeWindowSeconds)
    let recentHistoricalCarbs = historicalCarbs.filter { entry in
        let entryDate = entry.actualDate ?? entry.createdAt ?? Date.distantPast
        return entryDate > cutoffTime && entry.carbs > 0
    }
    
    logMessage += "\n=== MULTIPLE MEAL DETECTION ===\n"
    logMessage += "Time window: \(Int(largeMealTimeWindow)) minutes\n"
    logMessage += "Threshold: \(largeMealThreshold)g\n"
    logMessage += "\nData sources found:\n"
    logMessage += "• CoreDataStorage: \(coreDataMeals.count) entries (includes cancelled)\n"
    logMessage += "• Saved carbs only: \(recentHistoricalCarbs.count) entries (History screen data)\n"
    
    guard !recentHistoricalCarbs.isEmpty else {
        logMessage += "\nNo confirmed saved carb entries in time window\n"
        logMessage += "Multiple meal detection: DISABLED\n"
        return 0
    }
    
    // Convert to compatible format
    struct MealFromCarbs {
        let carbs: Double
        let createdAt: Date?
        
        init(from entry: CarbsEntry) {
            self.carbs = Double(entry.carbs)
            self.createdAt = entry.actualDate ?? entry.createdAt
        }
    }
    
    let confirmedMeals = recentHistoricalCarbs.map { MealFromCarbs(from: $0) }
    
    logMessage += "\nConfirmed saved meals being analyzed:\n"
    for (index, meal) in confirmedMeals.enumerated() {
        let ageMinutes = Int(currentTime.timeIntervalSince(meal.createdAt ?? Date()) / 60)
        logMessage += "• Entry \(index + 1): \(meal.carbs)g (\(ageMinutes) min ago)\n"
    }
    
    // Calculate active carbs using absorption model
    var min_hourly_carb_absorption = Decimal(carbAbsorptionRate)
    var min_5m_carbabsorption: Decimal = 0
    min_5m_carbabsorption = min_hourly_carb_absorption / (60 / 5)
    
    var totalActiveCarbs: Decimal = 0
    
    logMessage += "\nAbsorption analysis (rate: \(min_hourly_carb_absorption)g/hour):\n"
    
    for (index, meal) in confirmedMeals.enumerated() {
        let mealAge = currentTime.timeIntervalSince(meal.createdAt ?? Date()) / 60
        let originalCarbs = Decimal(meal.carbs)
        let fiveMinutePeriods = Int(mealAge / 5)
        let absorbedCarbs = Decimal(fiveMinutePeriods) * min_5m_carbabsorption
        let activeCarbs = max(0, originalCarbs - absorbedCarbs)
        totalActiveCarbs += activeCarbs
        
        let timeAgo = Int(mealAge)
        logMessage += "• \(originalCarbs)g (\(timeAgo)min) - \(roundToHundredth(absorbedCarbs))g absorbed = \(roundToHundredth(activeCarbs))g active\n"
    }
    
    let totalRawCarbs = confirmedMeals.reduce(0) { $0 + Decimal($1.carbs) }
    logMessage += "\nSummary:\n"
    logMessage += "• Total raw carbs: \(totalRawCarbs)g\n"
    logMessage += "• Total active carbs: \(roundToHundredth(totalActiveCarbs))g\n"
    
    // Only proceed if we have multiple meals OR if single meal benefits from multiple meal logic
    let currentCarbs = getEffectiveRecentCarbs()
    let isMultipleMeals = confirmedMeals.count > 1
    let wouldBenefitFromMultiple = totalActiveCarbs > currentCarbs + 5 // 5g buffer
    
    guard isMultipleMeals || wouldBenefitFromMultiple else {
        logMessage += "• Single meal scenario with no benefit from multiple meal logic\n"
        return 0
    }
    
    // Use tiered dosing function for multiple meals
    logMessage += "• Multiple meal scenario detected - calculating combined dosing\n"
    
    let multipleInsulin = calculateTieredInsulin(
        totalCarbs: totalActiveCarbs, 
        includeCorrections: true, 
        logPrefix: "Multiple: "
    )
    
    return multipleInsulin > 0 ? roundBolus(multipleInsulin) : 0
}
        

    // COMPLETE calculateInsulin function
    func calculateInsulin(manualCarbEntry: Decimal? = nil) -> Decimal {
    let conversion: Decimal = units == .mmolL ? 0.0555 : 1

    // Update the instance variable if provided
    if let manualEntry = manualCarbEntry {
        self.manualCarbEntry = manualEntry
    }

    // Get the most appropriate carb entry to use
    let effectiveCarbs = getEffectiveRecentCarbs()

    // CLEAR LOGGING for standard logic
    logMessage = "=== STANDARD CALCULATION ANALYSIS ===\n"
    logMessage += "Current session carbs: \(carbToStore.first?.carbs ?? 0)g\n"
    logMessage += "Effective carbs for calculation: \(effectiveCarbs)g\n"
    
    if effectiveCarbs > 0 {
        logMessage += "Source: Current session (newly entered)\n"
    } else {
        logMessage += "Source: None (direct insulin access or no new carbs)\n"
    }

    // The actual glucose threshold
    threshold = max(target - 0.5 * (target - 40 * conversion), threshold * conversion)

    // Calculate BG correction components
    if eventualBG {
        if evBG > target {
            insulin = (evBG - target) / isf
        } else { insulin = 0 }
    } else if currentBG == 0, manualGlucose > 0 {
        let targetDifference = manualGlucose * conversion - target
        if targetDifference > 0 {
            targetDifferenceInsulin = isf == 0 ? 0 : targetDifference / isf
        } else {
            targetDifferenceInsulin = 0
        }
    } else if currentBG != 0 {
        let targetDifference = currentBG - (units == .mmolL ? target.asMgdL : target)
        if targetDifference > 0 {
            targetDifferenceInsulin = isf == 0 ? 0 : targetDifference / (units == .mmolL ? isf.asMgdL : isf)
        } else {
            targetDifferenceInsulin = 0
        }
    } else {
        targetDifferenceInsulin = 0
    }

    // more or less insulin because of bg trend in the last 15 minutes
    // YOUR MODIFICATION: Disabled trend insulin
    //fifteenMinInsulin = isf == 0 ? 0 : (deltaBG * conversion) / isf

    // Calculate insulin using tiered dosing function
    if effectiveCarbs > 0 {
        // Use new tiered dosing function for all carb calculations
        insulinCalculated = calculateTieredInsulin(
            totalCarbs: effectiveCarbs, 
            includeCorrections: true, 
            logPrefix: ""
        )
        
        // Apply fatty meal correction if enabled
        if useFattyMealCorrectionFactor {
            logMessage += "\nFatty meal correction applied: \(fattyMealFactor)x"
            insulinCalculated = insulinCalculated * fattyMealFactor
        }
    } else {
        logMessage += "\nNo new carbs - recommendation disabled\n"
        if targetDifferenceInsulin > 0 {
            logMessage += "Would recommend \(roundToHundredth(targetDifferenceInsulin))U for BG correction only\n"
        }
        insulinCalculated = 0
    }

    // Check for large meal override (multiple meals)
    let largeMealInsulin = checkForMultipleCarbEntries(currentCalculatedInsulin: insulinCalculated)
    if largeMealInsulin > 0 {
        logMessage += "\n" + "=".repeating(50) + "\n"
        logMessage += "MULTIPLE MEAL OVERRIDE ACTIVE\n"
        logMessage += "Single meal calculation: \(roundToHundredth(insulinCalculated))U\n"
        logMessage += "Multiple meal total: \(roundToHundredth(largeMealInsulin))U\n"
        logMessage += "USING MULTIPLE MEAL CALCULATION\n"
        insulinCalculated = largeMealInsulin
    }

    // Final bounds checking
    insulinCalculated = roundBolus(insulinCalculated)
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

        /// When IOB module fail - NEW BASE ENHANCED VERSION
        var recentIOB: Decimal {
            guard iob == 0 else { return 0 }
            guard let recent = coreDataStorage.recentReason() else { return 0 }
            let timeDifference = (recent.date ?? .distantPast).timeIntervalSinceNow
            if timeDifference <= 0, timeDifference > -30.minutes.timeInterval {
                let recent = ((recent.iob ?? 0) as Decimal)
                let pumpHistory = history?
                    .filter({ $0.timestamp.timeIntervalSinceNow > timeDifference && $0.type == .bolus })
                    .compactMap(\.amount).reduce(0, +) ?? 0
                return recent + pumpHistory
            } else if let history = history {
                let total = history
                    .filter({ $0.timestamp.timeIntervalSinceNow > -360.minutes.timeInterval && $0.type == .bolus })
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
                if let suggestion = self.suggestion {
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
                    self.insulinCalculated = self.roundBolus(max(self.calculateInsulin(), 0))
                    self.prepareData()
                }
            }
        }

        func backToCarbsView(override: Bool, editMode: Bool) {
            showModal(for: .addCarbs(editMode: editMode, override: override))
        }

        func carbsView(fetch: Bool, hasFatOrProtein _: Bool, mealSummary _: FetchedResults<Meals>) -> Bool {
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

        // NEW BASE ADDITION: Manual glucose function
        func addManualGlucose() {
            let glucose = units == .mmolL ? manualGlucose.asMgdL : manualGlucose
            let now = Date()
            let id = UUID().uuidString

            let saveToJSON = BloodGlucose(
                _id: id,
                sgv: Int(glucose),
                date: Decimal(now.timeIntervalSince1970) * 1000,
                dateString: now,
                glucose: Int(glucose),
                type: GlucoseType.manual.rawValue
            )
            provider.glucoseStorage.storeGlucose([saveToJSON])
            debug(.default, "Manual Glucose saved to glucose.json")
            // Save to Health
            var saveToHealth = [BloodGlucose]()
            saveToHealth.append(saveToJSON)
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

        // REPLACE the entire existing method with this version
        func setupBolusData() {
            if let recent = coreDataStorage.recentMeal() {
                let now = Date()
                if let mealTime = recent.createdAt, abs(now.timeIntervalSince(mealTime)) < 600 {
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
                } else {
                    carbToStore = []
                }
            } else {
                carbToStore = []
            }
    
            // Rest of method stays the same...
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
