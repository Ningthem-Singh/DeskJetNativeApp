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
        // Auto-refresh printer health every 15 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshStatusOnly()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Discovery
    public func discoverPrinterPort() -> (host: String, port: Int)? {
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
                return (host, port)
            }
        } catch {
            print("Discovery error: \(error)")
        }
        return nil
    }
    
    // MARK: - Full Refresh
    public func refreshAll() async {
        isLoading = true
        errorMessage = nil
        
        guard let (host, port) = discoverPrinterPort() else {
            printerInfo.isConnected = false
            errorMessage = "Printer not detected on USB. Please check USB connection."
            isLoading = false
            return
        }
        
        printerInfo.host = host
        printerInfo.port = port
        printerInfo.isConnected = true
        
        await fetchProductStatus()
        await fetchConsumables()
        await fetchCapabilities()
        await fetchQueue()
        
        isLoading = false
    }
    
    public func refreshStatusOnly() async {
        guard printerInfo.isConnected && printerInfo.port > 0 else { return }
        await fetchProductStatus()
        await fetchQueue()
    }
    
    // MARK: - HTTP Fetchers
    private func fetchProductStatus() async {
        guard let url = URL(string: "http://\(printerInfo.host):\(printerInfo.port)/DevMgmt/ProductStatusDyn.xml") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
        guard let url = URL(string: "http://\(printerInfo.host):\(printerInfo.port)/DevMgmt/ConsumableConfigDyn.xml") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
        guard let url = URL(string: "http://\(printerInfo.host):\(printerInfo.port)/eSCL/ScannerCapabilities") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
        if printerInfo.port > 0, let url = URL(string: "http://\(printerInfo.host):\(printerInfo.port)/") {
            NSWorkspace.shared.open(url)
        }
    }
}
