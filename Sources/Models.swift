import Foundation
import SwiftUI

// MARK: - Ink Cartridge Model
public struct InkCartridge: Identifiable, Sendable {
    public var id: String { labelCode }
    public let labelCode: String // "K" or "CMY"
    public let name: String      // "Black" or "Tri-Color"
    public let cartridgeNumber: String // "680"
    public let percentage: Int
    public let statusMessage: String
    
    public var color: Color {
        switch labelCode {
        case "K":
            return .black
        case "CMY":
            return .cyan
        default:
            return .blue
        }
    }
}

// MARK: - Printer Info Model
public struct PrinterInfo: Sendable {
    public var makeAndModel: String = "HP DeskJet 2600 series"
    public var serialNumber: String = ""
    public var firmwareVersion: String = ""
    public var host: String = "localhost"
    public var port: Int = 0        // IPP Port (e.g. 58771 on USB, 631 on Wi-Fi)
    public var httpPort: Int = 80   // HTTP Web Port (e.g. 58771 on USB, 80 on Wi-Fi)
    public var scannerPort: Int = 8080 // Dedicated AirScan eSCL Port (8080 on Wi-Fi, dynamic on USB)
    public var ipAddress: String = "127.0.0.1" // Resolved IPv4 address
    public var isWifi: Bool = false
    public var statusCategory: String = "Unknown"
    public var isConnected: Bool = false
    public var cupsQueueName: String = "HP_DeskJet_2600_series"
    public var cartridges: [InkCartridge] = []
    
    public var connectionLabel: String {
        if !isConnected {
            return "Offline"
        }
        return isWifi ? "Wi-Fi Online (\(ipAddress))" : "USB Online"
    }
    
    public var isPowerSave: Bool {
        return statusCategory.lowercased().contains("powersave")
    }
    
    public var friendlyStatus: String {
        if !isConnected {
            return "Disconnected"
        }
        let lower = statusCategory.lowercased()
        if lower.contains("powersave") {
            return "Energy Saver (Ready)"
        } else if lower.contains("idle") {
            return "Idle (Ready)"
        } else if lower.contains("trayempty") || lower.contains("trayopen") {
            return "Attention: Paper Tray Empty / Open"
        } else if lower.contains("printing") || lower.contains("processing") {
            return "Printing / Busy"
        }
        return statusCategory.capitalized
    }
}

// MARK: - Scanner Options
public enum ScanResolution: Int, CaseIterable, Identifiable, Sendable {
    case dpi75 = 75
    case dpi100 = 100
    case dpi200 = 200
    case dpi300 = 300
    case dpi600 = 600
    
    public var id: Int { rawValue }
    public var description: String {
        switch self {
        case .dpi75: return "75 DPI (Draft / Fast)"
        case .dpi100: return "100 DPI"
        case .dpi200: return "200 DPI"
        case .dpi300: return "300 DPI (Recommended / Sharp)"
        case .dpi600: return "600 DPI (High Detail)"
        }
    }
}

public enum ScanColorMode: String, CaseIterable, Identifiable, Sendable {
    case rgb24 = "RGB24"
    case grayscale8 = "Grayscale8"
    case blackAndWhite1 = "BlackAndWhite1"
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .rgb24: return "Full Color"
        case .grayscale8: return "Grayscale"
        case .blackAndWhite1: return "Black & White (Text)"
        }
    }
    public var shortTitle: String {
        switch self {
        case .rgb24: return "Color"
        case .grayscale8: return "Grayscale"
        case .blackAndWhite1: return "B&W"
        }
    }
}

public enum ScanOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "image/jpeg"
    case pdf = "application/pdf"
    
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .jpeg: return "JPEG Image"
        case .pdf: return "PDF Document"
        }
    }
    public var shortName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .pdf: return "PDF"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .pdf: return "pdf"
        }
    }
}

public enum ScanState: Equatable, Sendable {
    case idle
    case preparing
    case scanning
    case downloading
    case finished
    case failed(String)
}

// MARK: - CUPS Print Job
public struct CupsPrintJob: Identifiable, Sendable {
    public let id: String
    public let user: String
    public let file: String
    public let size: String
    public let state: String
}

// MARK: - Wi-Fi Access Point Model
public struct WifiAP: Identifiable, Hashable, Sendable {
    public var id: String { bssid.isEmpty ? hexSsid : bssid }
    public let ssid: String
    public let hexSsid: String
    public let bssid: String
    public let signalStrength: Int // 0 to 3
    public let dbm: Int
    public let encryptionType: String
    
    public var isSecure: Bool {
        return encryptionType.lowercased() != "none"
    }
    
    public var signalIconName: String {
        switch signalStrength {
        case 3...: return "wifi"
        case 2: return "wifi"
        case 1: return "wifi"
        default: return "wifi.slash"
        }
    }
}

