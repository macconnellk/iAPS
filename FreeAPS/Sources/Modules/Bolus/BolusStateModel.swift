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
      
        // Tiered dosing approach
        // SIMPLIFIED: Try direct approach first - may work better
func checkForMultipleCarbEntries(currentCalculatedInsulin: Decimal) -> Decimal {
    // Check if large meal mode is enabled
    guard enableLargeMealMode else { return 0 }
    
    let currentTime = Date()
    let largeMealThresholdDecimal = Decimal(largeMealThreshold)
    let timeWindowSeconds = largeMealTimeWindow * 60
    let startTime = currentTime.addingTimeInterval(-timeWindowSeconds)
    
    // Get current entry being calculated
    let currentCarbs = meal?.first?.carbs ?? 0
    guard currentCarbs > 0 else {
        logMessage += "\n\nNo current carb entry for large meal detection"
        return 0
    }
    
    // SIMPLIFIED: Try synchronous approach first
    var savedEntries: [StoredCarbEntry] = []
    var fetchCompleted = false
    
    logMessage += "\n\nFetching recent carb entries from carbsStorage..."
    
    carbsStorage.getCarbEntries(start: startTime, end: currentTime) { result in
        switch result {
        case .success(let entries):
            savedEntries = entries
            logMessage += "\nSuccessfully fetched \(entries.count) carb entries"
        case .failure(let error):
            logMessage += "\nFailed to fetch carb entries: \(error.localizedDescription)"
            savedEntries = []
        }
        fetchCompleted = true
    }
    
    // Simple polling wait (less complex than DispatchGroup)
    let startWait = Date()
    let maxWaitTime: TimeInterval = 10.0
    
    while !fetchCompleted && Date().timeIntervalSince(startWait) < maxWaitTime {
        Thread.sleep(forTimeInterval: 0.1) // Wait 100ms between checks
    }
    
    if !fetchCompleted {
        logMessage += "\n🔴 TIMEOUT: Could not fetch carb entries after 10 seconds"
        logMessage += "\nUsing current entry only - large meal detection incomplete"
        savedEntries = []
    }
    
    // Filter valid entries
    let validSavedEntries = savedEntries.filter { entry in
        let entryAge = currentTime.timeIntervalSince(entry.startDate)
        let isWithinWindow = entryAge >= 0 && entryAge <= timeWindowSeconds
        let hasValidCarbs = entry.quantity.doubleValue(for: .gram()) > 0
        return isWithinWindow && hasValidCarbs
    }
    
    // Create current entry
    let currentEntry = (carbs: Double(currentCarbs), date: currentTime)
    
    // Combine all entries
    var allEntries: [(carbs: Double, date: Date)] = []
    allEntries.append(contentsOf: validSavedEntries.map { 
        (carbs: $0.quantity.doubleValue(for: .gram()), date: $0.startDate) 
    })
    allEntries.append(currentEntry)
    
    // Sort by date
    allEntries.sort { $0.date < $1.date }
    
    guard !allEntries.isEmpty else {
        logMessage += "\n\nNo valid entries found"
        return 0
    }
    
    // Report data status
    if validSavedEntries.isEmpty && !fetchCompleted {
        logMessage += "\n🔴 DATA WARNING: Using current entry only due to fetch timeout"
    } else if validSavedEntries.isEmpty {
        logMessage += "\n✅ DATA OK: No saved entries found (single meal)"
    } else {
        logMessage += "\n✅ DATA OK: Found \(validSavedEntries.count) saved + 1 current entry"
    }
    
    // Calculate active carbs
    let min_hourly_carb_absorption = Decimal(carbAbsorptionRate)
    let min_5m_carbabsorption = min_hourly_carb_absorption / (60 / 5)
    var totalActiveCarbs: Decimal = 0
    
    logMessage += "\n\nLarge Meal Analysis:"
    logMessage += "\nTime window: \(Int(largeMealTimeWindow)) minutes"
    logMessage += "\nUsing absorption: \(min_hourly_carb_absorption)g/hour"
    
    for (index, entry) in allEntries.enumerated() {
        let mealAge = currentTime.timeIntervalSince(entry.date) / 60
        let originalCarbs = Decimal(entry.carbs)
        let fiveMinutePeriods = Int(max(0, mealAge) / 5)
        let absorbedCarbs = Decimal(fiveMinutePeriods) * min_5m_carbabsorption
        let activeCarbs = max(0, originalCarbs - absorbedCarbs)
        totalActiveCarbs += activeCarbs
        
        let timeAgo = Int(max(0, mealAge))
        let entryType = (index == allEntries.count - 1) ? "CURRENT" : "SAVED"
        logMessage += "\n\(entryType): \(originalCarbs)g (\(timeAgo)min ago) = \(roundToHundredth(activeCarbs))g active"
    }
    
    logMessage += "\nTOTAL ACTIVE: \(roundToHundredth(totalActiveCarbs))g"
    
    // Check threshold
    guard totalActiveCarbs > largeMealThresholdDecimal else {
        logMessage += "\nBelow threshold \(largeMealThresholdDecimal)g - No large meal correction"
        return 0
    }
    
    // Tiered dosing
    let baseCarbs = min(totalActiveCarbs, largeMealThresholdDecimal)
    let additionalCarbs = max(0, totalActiveCarbs - largeMealThresholdDecimal)
    let baseInsulin = baseCarbs / carbRatio
    let additionalInsulin = (additionalCarbs / carbRatio) * Decimal(largeMealFraction)
    let totalLargeMealInsulin = baseInsulin + additionalInsulin
    
    // Add corrections
    let totalWithBGCorrection = totalLargeMealInsulin + targetDifferenceInsulin
    let iobReduction = iob > 0 ? iob : 0
    let largeMealBeforeSafety = max(0, totalWithBGCorrection - iobReduction)
    let safetyMaxInsulin: Decimal = min(6.0, maxBolus * 0.8)
    let cappedLargeMealInsulin = min(largeMealBeforeSafety, safetyMaxInsulin)
    
    logMessage += "\nLARGE MEAL CALCULATION:"
    logMessage += "\nBase \(roundToHundredth(baseCarbs))g@100%: \(roundToHundredth(baseInsulin))U"
    logMessage += "\nExtra \(roundToHundredth(additionalCarbs))g@\(Int(largeMealFraction * 100))%: \(roundToHundredth(additionalInsulin))U"
    logMessage += "\nTotal carb insulin: \(roundToHundredth(totalLargeMealInsulin))U"
    logMessage += "\nWith BG correction: \(roundToHundredth(totalWithBGCorrection))U"
    logMessage += "\nMinus IOB: \(roundToHundredth(cappedLargeMealInsulin))U"
    
    // Apply safety reductions
    let safeLargeMealInsulin = applySafetyReductions(rawInsulin: cappedLargeMealInsulin, isLargeMeal: true)
    
    logMessage += "\nFINAL LARGE MEAL: \(roundToHundredth(safeLargeMealInsulin))U"
    
    return safeLargeMealInsulin > 0 ? roundBolus(safeLargeMealInsulin) : 0
}

 

        
        // YOUR REPLACEMENT: Enhanced calculateInsulin with logging and safety
        func calculateInsulin(manualCarbEntry: Decimal? = nil) -> Decimal {
            let conversion: Decimal = units == .mmolL ? 0.0555 : 1

            // Update the instance variable if provided
            if let manualEntry = manualCarbEntry {
                self.manualCarbEntry = manualEntry
            }

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
                //Leave insulin value at 0 when BG is at or below target
                if targetDifference > 0 {
                    targetDifferenceInsulin = isf == 0 ? 0 : targetDifference / isf
                } else {
                    targetDifferenceInsulin = 0
                }
            } else if currentBG != 0 {
                let targetDifference = currentBG - (units == .mmolL ? target.asMgdL : target)
                //Leave insulin value at 0 when BG is at or below target
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

            // YOUR ENHANCED COB CALCULATION with logging
            wholeCobInsulin = carbRatio != 0 ? cob / carbRatio : 0
            log_COBapproach = "COB Value"
            logMessage = "Using COB Approach:\n"

            // YOUR ADDITION: Assess COB special cases
            if effectiveCarbs > 0 {
                // If COB is unexpectedly 0 but we have effectiveCarbs, use effectiveCarbs for COB value up to maxCOB
                if cob == 0 {
                    wholeCobInsulin = carbRatio != 0 ? min(effectiveCarbs, maxCOB) / carbRatio : 0
                    // Turn off oref predictions blend bc not reliable without COB data
                    minimumPrediction = false
                }

                // For high carb meals, disreagrd maxCOB approach. Allows violation of maxCOB and ensures more insulin dosed up front for high carb meals
                // Calculate a fraction of the total carb-based insulin and set COB insulin to the higher value
                if effectiveCarbs > maxCOB {
                    carbInsulinFraction = carbRatio != 0 ? effectiveCarbs / carbRatio : 0
                    carbInsulinFraction = carbInsulinFraction * fraction

                    // Log the COB Calculated Insulin Approach
                    if carbInsulinFraction > wholeCobInsulin {
                        log_COBapproach = "Large Meal Fraction"
                        logMessage = "Using Large Meal Approach:\n"
                    }

                    wholeCobInsulin = max(wholeCobInsulin, carbInsulinFraction)
                }
            }

            // determine how much the calculator reduces the bolus because of IOB; bolus will not be increased for negative IOB
            if iob > 0 {
                iobInsulinReduction = (-1) * iob
            }

            // adding everything together for COB approach
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

            // YOUR ADDITION: Format values for logging with proper precision
            log_roundedWholeCalc = roundToHundredth(wholeCalc)
            log_roundedtargetDifferenceInsulin = roundToHundredth(targetDifferenceInsulin)
            log_roundedwholeCobInsulin = roundToHundredth(wholeCobInsulin)
            log_roundediobInsulinReduction = roundToHundredth(iobInsulinReduction)

            // YOUR ADDITION: Now calculate insulin for the latest full carb entry if within last ten minutes
            if effectiveCarbs > 0 {
                // Calculate insulin for latest carb entry
                latestCarbEntryInsulin = (effectiveCarbs / carbRatio)
                wholeCalc_carbs = latestCarbEntryInsulin + targetDifferenceInsulin
                log_manualCarbEntry_used = effectiveCarbs

                // Calculate final values with clear explanation of which was chosen
                let originalWholeCalc = wholeCalc
                wholeCalc = min(wholeCalc, wholeCalc_carbs)

                // Log the approach
                if wholeCalc == wholeCalc_carbs {
                logMessage = "Using Small Carb Approach:\n"
                log_COBapproach = "Small Meal Carb Entry"    
                }

                // Format updated values for logging with proper precision
                roundedLatestCarbEntryInsulin = roundToHundredth(latestCarbEntryInsulin)
                roundedwholeCalc_carbs = roundToHundredth(wholeCalc_carbs)
                log_roundedWholeCalc = roundToHundredth(wholeCalc)

                // YOUR DETAILED LOGGING
                logMessage += "Carbs: \(log_manualCarbEntry_used)g, Insulin: \(roundedLatestCarbEntryInsulin)g\n"
            if log_COBapproach == "COB Value" {
                logMessage += "COB: \(cob)g, Insulin: \(log_roundedwholeCobInsulin)g\n"
            } else {
                logMessage += "Large Meal Fraction: \(log_manualCarbEntry_used)g, Insulin: \(log_roundedwholeCobInsulin)g\n"
            }
                logMessage += "Insulin Determined By: \(log_COBapproach)\n"
                logMessage += "Correction: \(log_roundedtargetDifferenceInsulin)U\n"
                logMessage += "IOB: \(log_roundediobInsulinReduction)U\n"
                logMessage += "Total Insulin: \(log_roundedWholeCalc)U\n"

                logMessage += "\nDetailed Calculations:\n"
                // Carb calculation component
                logMessage += "Carb insulin: \(roundedLatestCarbEntryInsulin)U"
                logMessage += " (\(log_manualCarbEntry_used)g ÷ \(carbRatio))\n"
                // COB calculation component selected larger of COB insulin or Large Meal insulin
            if log_COBapproach == "COB Value" {
                logMessage += "COB: \(log_roundedwholeCobInsulin)U"
                logMessage += " (\(cob)g ÷ \(carbRatio))\n"
            } else {
                logMessage += "Large Meal Fraction insulin: \(log_roundedwholeCobInsulin)U"
                logMessage += " (\(log_manualCarbEntry_used)g ÷ \(carbRatio) * \(fraction))\n"
            }

                // BG correction component with comprehensive explanation
                if targetDifferenceInsulin > 0 {
                    logMessage += "BG correction: \(log_roundedtargetDifferenceInsulin)U"
                    logMessage += " (BG: \(currentBG) - \(target)) ÷ ISF \(isf)\n"
                } else {
                    logMessage += "BG correction: 0U (BG at or below target)\n"
                }

                // IOB component
                logMessage += "IOB adjustment: \(log_roundediobInsulinReduction)U\n"
            } else {
                // Decision Path at top
                logMessage = "No New Carbs. Recommendation Disabled, would be\n"

                if targetDifferenceInsulin > 0 {
                    logMessage += "Correction: \(log_roundedtargetDifferenceInsulin)U\n"
                    logMessage += "IOB: \(log_roundediobInsulinReduction)U\n"
                } else {
                    logMessage += "No correction needed (BG at/below target)\n"
                    logMessage += "IOB: \(log_roundediobInsulinReduction)U\n"
                }

                logMessage += "Total Insulin: \(log_roundedWholeCalc)U\n"
                wholeCalc = 0

                // Add detailed calculations
                logMessage += "\nDetailed Calculations:\n"
                if targetDifferenceInsulin > 0 {
                logMessage += "BG correction: \(log_roundedtargetDifferenceInsulin)U"
                    logMessage += " (BG: \(currentBG) - \(target)) ÷ ISF \(isf)\n"
                } else {
                    logMessage += "BG correction: 0U (BG at or below target)\n"
                }

                logMessage += "IOB adjustment: \(log_roundediobInsulinReduction)U\n"
            }

            // Rounding calculations
            roundedWholeCalc = roundToHundredth(wholeCalc)

            // apply custom factor at the end of the calculations
            // YOUR MODIFICATION: New code moves fraction up to the COB/Carb calculation for Swift Code
            let result = !eventualBG ? wholeCalc : insulin * fraction

            // apply custom factor if fatty meal toggle in bolus calc config settings is on and the box for fatty meals is checked (in RootView)
            if useFattyMealCorrectionFactor {
                insulinCalculated = result * fattyMealFactor
            } else {
                insulinCalculated = result
            }

            // Apply safety reductions using extracted function
            insulinCalculated = applySafetyReductions(rawInsulin: insulinCalculated, isLargeMeal: false)

            // Check for multiple carb entries and override with large meal calculation if needed
            let largeMealInsulin = checkForMultipleCarbEntries(currentCalculatedInsulin: insulinCalculated)
            if largeMealInsulin > 0 {
                logMessage += "\n\nLARGE MEAL DETECTED - OVERRIDING CALCULATION"
                logMessage += "\nOriginal calculation: \(roundToHundredth(insulinCalculated))U"
                logMessage += "\nLarge meal total: \(roundToHundredth(largeMealInsulin))U"
                insulinCalculated = largeMealInsulin
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

        func setupBolusData() {
            if let recent = coreDataStorage.recentMeal() {
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
