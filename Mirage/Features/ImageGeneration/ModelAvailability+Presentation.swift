import Foundation

public extension ModelAvailability {
    var title: String {
        switch self {
        case .checking: "Checking"
        case .available: "Available"
        case .configurationIncomplete: "Setup required"
        case .missingFiles: "Files missing"
        case .integrityFailed: "Files need verification"
        case .licenseNotApproved: "License review required"
        case .evaluationRequired: "Evaluation required"
        case .unsupportedDevice: "Not supported on this device"
        case .insufficientMemory: "Not enough available memory"
        case .protectedDataUnavailable: "Unlock device to continue"
        case .invalidPath: "Model location is invalid"
        case .incompatibleAssets: "Files are incompatible"
        }
    }

    var detail: String {
        switch self {
        case .checking:
            "Mirage is checking local compatibility."
        case .available:
            "Ready for on-device generation."
        case .configurationIncomplete:
            "A reviewed file manifest and hashes have not been configured."
        case .missingFiles(let names):
            names.isEmpty ? "Required model files are missing." : "Missing \(names.count) required file(s)."
        case .integrityFailed:
            "A local file did not match its approved size or checksum."
        case .licenseNotApproved:
            "This model remains disabled until its complete license set is approved."
        case .evaluationRequired:
            "This model remains disabled until quality and safety evaluation passes."
        case .unsupportedDevice:
            "This model has not been approved for this device."
        case .insufficientMemory:
            "Close other apps or choose a smaller approved model."
        case .protectedDataUnavailable:
            "Unlock the device so protected model files can be read."
        case .invalidPath:
            "Mirage only reads models from its protected Application Support folder."
        case .incompatibleAssets:
            "The local files do not match this model family."
        }
    }
}
