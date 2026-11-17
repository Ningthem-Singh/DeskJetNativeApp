import Foundation
import AppKit

@MainActor
public class PrinterService: ObservableObject {
    @Published public var printerInfo = PrinterInfo()
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var printQueue: [CupsPrintJob] = []
    
    private var refreshTimer: Timer?
    
    public init() {
        Task {
            await refreshAll()
        }
        // Auto-refresh printer health every 60 seconds (prevents Wi-Fi socket contention)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshStatusOnly()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Discovery
    // MARK: - Discovery
    public func discoverPrinter() -> (host: String, httpHost: String, ippPort: Int, httpPort: Int, scannerPort: Int, isWifi: Bool)? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ippfind")
        task.arguments = ["_ipp._tcp"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let firstLine = output.components(separatedBy: .newlines).first,
               let url = URL(string: firstLine),
               let host = url.host,
               let port = url.port {
                
                let isLocalUSB = (host == "localhost" || host == "127.0.0.1")
                if isLocalUSB {
                    return (host: "localhost", httpHost: "127.0.0.1", ippPort: port, httpPort: port, scannerPort: port, isWifi: false)
                } else {
                    // Over Wi-Fi: Resolve IPv4 address to prevent macOS link-local IPv6 hangs
                    let resolvedIP = resolveIPv4(hostname: host) ?? host
                    return (host: host, httpHost: resolvedIP, ippPort: port, httpPort: 80, scannerPort: 8080, isWifi: true)
                }
            }
        } catch {
            print("Discovery error: \(error)")
        }
        return nil
    }
    
    private func resolveIPv4(hostname: String) -> String? {
        if hostname == "localhost" || hostname == "127.0.0.1" { return "127.0.0.1" }
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(hostname, nil, &hints, &res) == 0, let first = res else { return nil }
        defer { freeaddrinfo(res) }
        
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(first.pointee.ai_addr, first.pointee.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
            return String(cString: buffer)
        }
        return nil
    }
    
    // MARK: - Full Refresh
    public func refreshAll() async {
        isLoading = true
        errorMessage = nil
        
        guard let disc = discoverPrinter() else {
            printerInfo.isConnected = false
            errorMessage = "Printer not detected. Please check USB connection or Wi-Fi network."
            isLoading = false
            return
        }
        
        printerInfo.host = disc.host
        printerInfo.ipAddress = disc.httpHost
        printerInfo.port = disc.ippPort
        printerInfo.httpPort = disc.httpPort
        printerInfo.scannerPort = disc.scannerPort
        printerInfo.isWifi = disc.isWifi
        printerInfo.isConnected = true
        
        await fetchProductStatus()
        await fetchConsumables()
        await fetchCapabilities()
        await fetchQueue()
        
        isLoading = false
    }
    
    public func refreshStatusOnly() async {
        guard printerInfo.isConnected && printerInfo.httpPort > 0 else { return }
        await fetchProductStatus()
        await fetchQueue()
    }
    
    // MARK: - HTTP Fetchers
    private func fetchProductStatus() async {
        guard let url = URL(string: "http://\(printerInfo.ipAddress):\(printerInfo.httpPort)/DevMgmt/ProductStatusDyn.xml") else { return }
        do {
            var request = URLRequest(url: url, timeoutInterval: 6.0)
            request.setValue("close", forHTTPHeaderField: "Connection")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let parser = ProductStatusParser()
                let xml = XMLParser(data: data)
                xml.delegate = parser
                if xml.parse() {
                    printerInfo.statusCategory = parser.statusCategory
                }
            }
        } catch {
            print("Status fetch error: \(error)")
        }
    }
    
    private func fetchConsumables() async {
        guard let url = URL(string: "http://\(printerInfo.ipAddress):\(printerInfo.httpPort)/DevMgmt/ConsumableConfigDyn.xml") else { return }
        do {
            var request = URLRequest(url: url, timeoutInterval: 6.0)
            request.setValue("close", forHTTPHeaderField: "Connection")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let parser = ConsumablesParser()
                let xml = XMLParser(data: data)
                xml.delegate = parser
                if xml.parse() {
                    printerInfo.cartridges = parser.cartridges
                }
            }
        } catch {
            print("Consumables fetch error: \(error)")
        }
    }
    
    private func fetchCapabilities() async {
        guard let url = URL(string: "http://\(printerInfo.ipAddress):\(printerInfo.httpPort)/eSCL/ScannerCapabilities") else { return }
        do {
            var request = URLRequest(url: url, timeoutInterval: 6.0)
            request.setValue("close", forHTTPHeaderField: "Connection")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let parser = ScannerCapabilitiesParser()
                let xml = XMLParser(data: data)
                xml.delegate = parser
                if xml.parse() {
                    if !parser.makeAndModel.isEmpty {
                        printerInfo.makeAndModel = parser.makeAndModel
                    }
                    printerInfo.serialNumber = parser.serialNumber
                }
            }
        } catch {
            print("Capabilities fetch error: \(error)")
        }
    }
    
    // MARK: - Print Operations
    public func printFile(
        url: URL,
        copies: Int = 1,
        colorMode: String = "RGB",
        quality: String = "Normal",
        pageSize: String = "A4"
    ) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/lp")
        task.arguments = [
            "-d", printerInfo.cupsQueueName,
            "-n", "\(max(1, copies))",
            "-o", "ColorModel=\(colorMode)",
            "-o", "cupsPrintQuality=\(quality)",
            "-o", "PageSize=\(pageSize)",
            url.path
        ]
        
        let pipe = Pipe()
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown printing error"
            throw NSError(domain: "PrintService", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorStr])
        }
        
        await fetchQueue()
    }
    
    public func printTestPage() async throws {
        let testPrintPath = "/usr/share/cups/data/testprint"
        if FileManager.default.fileExists(atPath: testPrintPath) {
            try await printFile(url: URL(fileURLWithPath: testPrintPath))
        } else {
            // Generate a simple test page
            let tempDir = FileManager.default.temporaryDirectory
            let testFile = tempDir.appendingPathComponent("DeskJet_Test_Page.txt")
            let text = """
            ====================================================
                       HP DESKJET 2600 SERIES TEST PAGE
                       Apple Silicon (M-Series) Native Test
            ====================================================
            Date: \(Date().formatted())
            Printer: \(printerInfo.makeAndModel)
            Serial: \(printerInfo.serialNumber)
            Driver: Driverless IPP-over-USB AirPrint
            Architecture: Apple Silicon ARM64 Native
            ====================================================
            Print and Scan subsystem verified successfully!
            """
            try text.write(to: testFile, atomically: true, encoding: .utf8)
            try await printFile(url: testFile)
        }
    }
    
    // MARK: - Print Queue
    public func fetchQueue() async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        task.arguments = ["-o"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var jobs: [CupsPrintJob] = []
                for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 4 {
                        let id = parts[0]
                        let user = parts[1]
                        let size = parts[2]
                        let file = parts.dropFirst(3).joined(separator: " ")
                        jobs.append(CupsPrintJob(id: id, user: user, file: file, size: size, state: "Active"))
                    }
                }
                self.printQueue = jobs
            }
        } catch {
            print("Queue fetch error: \(error)")
        }
    }
    
    public func cancelJob(id: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/cancel")
        task.arguments = [id]
        try? task.run()
        task.waitUntilExit()
        Task { await fetchQueue() }
    }
    
    public func cancelAllJobs() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/cancel")
        task.arguments = ["-a", printerInfo.cupsQueueName]
        try? task.run()
        task.waitUntilExit()
        Task { await fetchQueue() }
    }
    
    // MARK: - System Shortcuts
    public func openImageCapture() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Image Capture.app"))
    }
    
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Print-Scan-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openEmbeddedWebServer() {
        if printerInfo.httpPort > 0, let url = URL(string: "http://\(printerInfo.ipAddress):\(printerInfo.httpPort)/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Wi-Fi Configuration
    public func fetchWifiNetworks() async throws -> [WifiAP] {
        guard printerInfo.httpPort > 0 else {
            throw NSError(domain: "PrinterService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Printer is not connected."])
        }
        guard let url = URL(string: "http://\(printerInfo.ipAddress):\(printerInfo.httpPort)/IoMgmt/Adapters/Wifi0/WifiNetworks") else {
            throw NSError(domain: "PrinterService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Wi-Fi URL"])
        }
        
        let request = URLRequest(url: url, timeoutInterval: 10.0)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "PrinterService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to scan Wi-Fi networks from printer."])
        }
        
        let parser = WifiNetworksParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        if xml.parse() {
            var unique: [String: WifiAP] = [:]
            for ap in parser.networks {
                if let existing = unique[ap.ssid] {
                    if ap.signalStrength > existing.signalStrength {
                        unique[ap.ssid] = ap
                    }
                } else {
                    unique[ap.ssid] = ap
                }
            }
            return unique.values.sorted { $0.signalStrength > $1.signalStrength }
        }
        return []
    }
    
    public func connectToWifi(ap: WifiAP, password: String) async throws {
        guard printerInfo.httpPort > 0 else {
            throw NSError(domain: "PrinterService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Printer is not connected."])
        }
        
        guard let url = URL(string: "http://\(printerInfo.ipAddress):\(printerInfo.httpPort)/IoMgmt/Adapters/Wifi0/Profiles/1") else {
            throw NSError(domain: "PrinterService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Wi-Fi Profile URL"])
        }
        
        let hexPass = password.utf8.map { String(format: "%02x", $0) }.joined()
        
        let deltaXml: String
        if ap.isSecure {
            deltaXml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <io:Profile xmlns:io="http://www.hp.com/schemas/imaging/con/ledm/iomgmt/2008/11/30" xmlns:wifi="http://www.hp.com/schemas/imaging/con/wifi/2009/06/26">
                <io:AdapterProfile>
                    <io:WifiProfile>
                        <wifi:SSID>\(ap.hexSsid)</wifi:SSID>
                        <wifi:BSSID>\(ap.bssid)</wifi:BSSID>
                        <io:KeyInfo>
                            <io:WpaPassPhraseInfo>
                                <wifi:PassPhrase>\(hexPass)</wifi:PassPhrase>
                            </io:WpaPassPhraseInfo>
                        </io:KeyInfo>
                    </io:WifiProfile>
                </io:AdapterProfile>
            </io:Profile>
            """
        } else {
            deltaXml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <io:Profile xmlns:io="http://www.hp.com/schemas/imaging/con/ledm/iomgmt/2008/11/30" xmlns:wifi="http://www.hp.com/schemas/imaging/con/wifi/2009/06/26">
                <io:AdapterProfile>
                    <io:WifiProfile>
                        <wifi:SSID>\(ap.hexSsid)</wifi:SSID>
                        <wifi:BSSID>\(ap.bssid)</wifi:BSSID>
                        <wifi:EncryptionType>none</wifi:EncryptionType>
                        <wifi:AuthenticationMode>open</wifi:AuthenticationMode>
                    </io:WifiProfile>
                </io:AdapterProfile>
            </io:Profile>
            """
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = deltaXml.data(using: .utf8)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "PrinterService", code: code, userInfo: [NSLocalizedDescriptionKey: "Printer returned error code \(code) while setting Wi-Fi."])
        }
    }
}
