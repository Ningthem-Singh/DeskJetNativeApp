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
