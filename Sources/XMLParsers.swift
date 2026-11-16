import Foundation

// MARK: - Consumables Parser
public class ConsumablesParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentLabelCode = ""
    private var currentSelectibilityNumber = "680"
    private var currentPercentage = 0
    private var currentLifeState = ""
    public var cartridges: [InkCartridge] = []
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        
        if currentElement.contains("ConsumableLabelCode") {
            currentLabelCode = trimmed
        } else if currentElement.contains("ConsumablePercentageLevelRemaining") {
            currentPercentage = Int(trimmed) ?? 0
        } else if currentElement.contains("ConsumableSelectibilityNumber") {
            currentSelectibilityNumber = trimmed
        } else if currentElement.contains("ConsumableState") {
            currentLifeState = trimmed
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.contains("ConsumableInfo") {
            if !currentLabelCode.isEmpty {
                let name = currentLabelCode == "K" ? "Black Ink" : "Tri-Color Ink"
                var stateDesc = "Ready"
                if currentLifeState.contains("newGenuine") {
                    stateDesc = "Genuine HP"
                } else if currentLifeState.contains("refilled") {
                    stateDesc = "Refilled / Generic"
                }
                
                let cartridge = InkCartridge(
                    labelCode: currentLabelCode,
                    name: name,
                    cartridgeNumber: "HP \(currentSelectibilityNumber)",
                    percentage: max(0, min(100, currentPercentage)),
                    statusMessage: stateDesc
                )
                cartridges.append(cartridge)
            }
            currentLabelCode = ""
            currentPercentage = 0
            currentLifeState = ""
        }
    }
}

// MARK: - Product Status Parser
public class ProductStatusParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    public var statusCategory: String = "Idle"
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        
        if currentElement.contains("StatusCategory") {
            statusCategory = trimmed
        }
    }
}

// MARK: - Scanner Capabilities Parser
public class ScannerCapabilitiesParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    public var makeAndModel: String = "HP DeskJet 2600 series"
    public var serialNumber: String = ""
    public var uuid: String = ""
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        
        if currentElement.contains("MakeAndModel") {
            makeAndModel = trimmed
        } else if currentElement.contains("SerialNumber") {
            serialNumber = trimmed
        } else if currentElement == "scan:UUID" || currentElement.hasSuffix(":UUID") {
            uuid = trimmed
        }
    }
}

// MARK: - Wi-Fi Networks Parser
public class WifiNetworksParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentText = ""
    private var curSSIDHex = ""
    private var curBSSID = ""
    private var curSignalStrength = 0
    private var curdBm = -100
    private var curEncryption = "WPA2"
    
    public var networks: [WifiAP] = []
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        
        if localName == "BSSID" {
            curBSSID = trimmed
        } else if localName == "SSID" {
            curSSIDHex = trimmed
        } else if localName == "SignalStrength" {
            curSignalStrength = Int(trimmed) ?? 0
        } else if localName == "dBm" {
            curdBm = Int(trimmed) ?? -100
        } else if localName == "EncryptionType" {
            curEncryption = trimmed
        } else if localName == "WifiNetwork" {
            if !curSSIDHex.isEmpty {
                // Decode hex string to ASCII
                let decodedSSID = decodeHex(curSSIDHex)
                if !decodedSSID.isEmpty {
                    let ap = WifiAP(
                        ssid: decodedSSID,
                        hexSsid: curSSIDHex,
                        bssid: curBSSID,
                        signalStrength: curSignalStrength,
                        dbm: curdBm,
                        encryptionType: curEncryption
                    )
                    networks.append(ap)
                }
            }
            curSSIDHex = ""
            curBSSID = ""
            curSignalStrength = 0
            curdBm = -100
            curEncryption = "WPA2"
        }
    }
    
    private func decodeHex(_ hex: String) -> String {
        var data = Data()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: min(2, hex.distance(from: idx, to: hex.endIndex)))
            let byteStr = String(hex[idx..<next])
            if let b = UInt8(byteStr, radix: 16) {
                data.append(b)
            }
            idx = next
        }
        return String(data: data, encoding: .utf8) ?? hex
    }
}

