import Foundation

// MARK: - Core Data Models

struct ParameterAnalysisData: Codable, Equatable {
    let timestamp: Date
    let glucoseReadings: [GlucoseReading]
    let treatments: [TreatmentData]
    let currentParameters: CurrentParameters
    let deviceStatus: [DeviceStatus]
    let parameterHistory: [ParameterChange]
}

struct GlucoseReading: Codable, Equatable {
    let date: Date
    let sgv: Int
    let direction: String?
    let isValid: Bool
    let isPressureLow: Bool
}

struct TreatmentData: Codable, Equatable {
    let date: Date
    let type: TreatmentType
    let carbs: Decimal?
    let insulin: Decimal?
    let iob: Decimal?
}

enum TreatmentType: String, Codable {
    case carbs = "Carb Correction"
    case bolus = "Bolus"
    case tempBasal = "Temp Basal"
}

struct CurrentParameters: Codable, Equatable {
    let basalRates: [BasalRate]
    let isfProfile: [ISFEntry]
    let crProfile: [CREntry]
    let csfRange: ClosedRange<Decimal>
}

struct BasalRate: Codable, Equatable {
    let start: String
    let rate: Decimal
    let minutes: Int
}

struct ISFEntry: Codable, Equatable {
    let start: String
    let sensitivity: Decimal
    let offset: Int
}

struct CREntry: Codable, Equatable {
    let start: String
    let ratio: Decimal
    let offset: Int
}

struct DeviceStatus: Codable, Equatable {
    let date: Date
    let iob: Decimal
    let basalIOB: Decimal
    let bolusIOB: Decimal
}

struct ParameterChange: Codable, Equatable {
    let date: Date
    let parameterType: ParameterType
    let timeBlock: String
    let oldValue: Decimal
    let newValue: Decimal
    let reason: String
}

enum ParameterType: String, Codable, CaseIterable {
    case basal = "Basal"
    case isf = "ISF"
    case cr = "CR"
}

// MARK: - Recommendation Models

struct ParameterRecommendations: Codable, Equatable {
    let analysisDate: Date
    let basalRecommendations: [BasalRecommendation]
    let isfRecommendations: [ISFRecommendation]
    let crRecommendations: [CRRecommendation]
    let safetyMetrics: SafetyMetrics
    let excludedData: ExcludedDataSummary
}

struct BasalRecommendation: Codable, Equatable {
    let timeBlock: String
    let currentRate: Decimal
    let recommendedRate: Decimal
    let changePercentage: Decimal
    let reason: String
    let detectionTime: Date
    let basalIOB: Decimal
    let glucoseValue: Int
    let priority: RecommendationPriority
}

struct ISFRecommendation: Codable, Equatable {
    let timeBlock: String
    let currentISF: Decimal
    let recommendedISF: Decimal
    let changePercentage: Decimal
    let reason: String
    let associatedCR: Decimal?
    let csfBefore: Decimal
    let csfAfter: Decimal
    let priority: RecommendationPriority
}

struct CRRecommendation: Codable, Equatable {
    let timeBlock: String
    let currentCR: Decimal
    let recommendedCR: Decimal
    let changePercentage: Decimal
    let reason: String
    let mealTime: Date
    let glucoseExcursion: Int
    let associatedISF: Decimal?
    let csfBefore: Decimal
    let csfAfter: Decimal
    let priority: RecommendationPriority
}

enum RecommendationPriority: String, Codable, CaseIterable {
    case critical = "Critical" // Hypoglycemia prevention
    case high = "High"         // Time in range optimization
    case medium = "Medium"     // Glycemic variability reduction
    case low = "Low"           // Fine-tuning
}

struct SafetyMetrics: Codable, Equatable {
    let timeBelow70: Decimal // Percentage
    let timeInRange70_160: Decimal // Percentage
    let glucoseStandardDeviation: Decimal
    let averageGlucose: Decimal
    let totalLowEvents: Int
    let severeLowEvents: Int // Below 54 mg/dL
}

struct ExcludedDataSummary: Codable, Equatable {
    let totalExcluded: Int
    let pressureLows: Int
    let invalidReadings: Int
    let excludedTimes: [Date]
}

struct AnalysisSettings: Codable {
    let csfRange: ClosedRange<Decimal>
    let timeInRangeTarget: Decimal
    let hypoglycemiaThreshold: Int
    let maxParameterChange: Decimal
    let maxSevereParameterChange: Decimal
    
    init() {
        self.csfRange = 6.0...12.0
        self.timeInRangeTarget = 90.0
        self.hypoglycemiaThreshold = 70
        self.maxParameterChange = 0.10
        self.maxSevereParameterChange = 0.25
    }
}

// MARK: - Extensions for Decimal range support

extension ClosedRange: Codable where Bound: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lowerBound = try container.decode(Bound.self, forKey: .lowerBound)
        let upperBound = try container.decode(Bound.self, forKey: .upperBound)
        self = lowerBound...upperBound
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lowerBound, forKey: .lowerBound)
        try container.encode(upperBound, forKey: .upperBound)
    }
    
    private enum CodingKeys: String, CodingKey {
        case lowerBound
        case upperBound
    }
}

// TEMPORARY TEST - Add this to the bottom of ParameterOptimizationModels.swift
func testParameterOptimizationModels() {
    let reading = GlucoseReading(
        date: Date(), 
        sgv: 120, 
        direction: "Flat", 
        isValid: true, 
        isPressureLow: false
    )
    print("✅ Step 1 works! Glucose: \(reading.sgv)")
    
    let settings = AnalysisSettings()
    print("✅ Settings work! TIR Target: \(settings.timeInRangeTarget)%")
}
