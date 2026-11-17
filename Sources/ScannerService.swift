import Foundation
import AppKit
import PDFKit

@MainActor
public class ScannerService: ObservableObject {
    @Published public var scanState: ScanState = .idle
    @Published public var progress: Double = 0.0
    @Published public var progressMessage: String = ""
    @Published public var scannedImage: NSImage? = nil
    @Published public var scannedData: Data? = nil
    
    // User Configuration
    @Published public var resolution: ScanResolution = .dpi300
    @Published public var colorMode: ScanColorMode = .rgb24
    @Published public var format: ScanOutputFormat = .jpeg
    
    public init() {}
    
    // MARK: - Execute eSCL Scan
    public func startScan(host: String, port: Int) async {
        guard port > 0 else {
            scanState = .failed("Printer connection is not available.")
            return
        }
        
        scanState = .preparing
        progress = 0.1
        progressMessage = "Connecting to scanner (\(host))..."
        
        // Candidates to probe: dedicated eSCL port (8080) and web proxy (80)
        let candidatePorts: [Int]
        if port == 80 || port == 8080 {
            candidatePorts = [8080, 80]
        } else {
            candidatePorts = [port]
        }
        
        var workingPort: Int = port
        var isReady = false
        var lastError: Error? = nil
        
        for candidate in candidatePorts {
            let statusURL = URL(string: "http://\(host):\(candidate)/eSCL/ScannerStatus")!
            for attempt in 1...2 {
                progressMessage = "Connecting to scanner on port \(candidate) (attempt \(attempt)/2)..."
                do {
                    var statusReq = URLRequest(url: statusURL, timeoutInterval: 8.0)
                    statusReq.setValue("close", forHTTPHeaderField: "Connection")
                    let (statusData, statusResp) = try await URLSession.shared.data(for: statusReq)
                    if let http = statusResp as? HTTPURLResponse {
                        if http.statusCode == 503 {
                            scanState = .failed("Scanner is busy or paused with a printer alert.\n\nPlease check your printer:\n1. Load paper into the rear input tray.\n2. Open the front output tray extender.\n3. Press the blinking Resume (orange paper) or Cancel (X) button on the printer to clear pending jobs.")
                            return
                        }
                        if http.statusCode == 200 {
                            let statusStr = String(data: statusData, encoding: .utf8) ?? ""
                            if statusStr.contains("<pwg:State>Processing</pwg:State>") || statusStr.contains("<pwg:State>Testing</pwg:State>") {
                                scanState = .failed("Scanner is currently busy. Please wait a moment and try again.")
                                return
                            }
                            workingPort = candidate
                            isReady = true
                            break
                        }
                    }
                } catch {
                    lastError = error
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            }
            if isReady { break }
        }
        
        guard isReady else {
            let desc = lastError?.localizedDescription ?? "The request timed out."
            scanState = .failed("Could not connect to scanner at \(host): \(desc)\n\nTroubleshooting tips:\n1. Check the printer panel: if the orange Resume (paper icon) button or Cancel (X) button is blinking, press Resume or Cancel to clear pending jobs or paper tray alerts.\n2. Ensure paper is in the rear input tray and the front output extender is pulled open.\n3. Verify the printer power light is solid.")
            return
        }
        
        progress = 0.25
        progressMessage = "Sending scan job parameters..."
        
        // 2. Build eSCL Scan Job Request
        let jobsURL = URL(string: "http://\(host):\(workingPort)/eSCL/ScanJobs")!
        var request = URLRequest(url: jobsURL, timeoutInterval: 25.0)
        request.httpMethod = "POST"
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("", forHTTPHeaderField: "Expect") // Prevent HP embedded server Expect: 100-continue hang
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        let xmlPayload = """
        <?xml version="1.0" encoding="UTF-8"?>
        <scan:ScanSettings xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
            <pwg:Version>2.62</pwg:Version>
            <scan:Intent>Document</scan:Intent>
            <pwg:InputSource>Platen</pwg:InputSource>
            <scan:InputSource>Platen</scan:InputSource>
            <scan:ColorMode>\(colorMode.rawValue)</scan:ColorMode>
            <scan:XResolution>\(resolution.rawValue)</scan:XResolution>
            <scan:YResolution>\(resolution.rawValue)</scan:YResolution>
            <pwg:DocumentFormat>\(format.rawValue)</pwg:DocumentFormat>
        </scan:ScanSettings>
        """
        request.httpBody = xmlPayload.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                scanState = .failed("Invalid server response from scanner.")
                return
            }
            
            if http.statusCode == 503 {
                scanState = .failed("Scanner is busy or paused with an alert. Please check: 1) Paper is loaded in the input tray, 2) The output tray is open, 3) Press the blinking Resume / Cancel button on the printer to clear any pending jobs.")
                return
            }
            
            guard http.statusCode == 201 else {
                scanState = .failed("Scanner rejected job with HTTP status \(http.statusCode)")
                return
            }
            
            // 3. Extract Job URL from Location header
            guard let locationHeader = http.value(forHTTPHeaderField: "Location") else {
                scanState = .failed("No job location returned by scanner.")
                return
            }
            
            let documentURLString: String
            let jobBaseURLString: String
            if locationHeader.hasPrefix("http") {
                jobBaseURLString = locationHeader
                documentURLString = "\(locationHeader)/NextDocument"
            } else {
                let cleanPath = locationHeader.hasPrefix("/") ? locationHeader : "/\(locationHeader)"
                jobBaseURLString = "http://\(host):\(workingPort)\(cleanPath)"
                documentURLString = "http://\(host):\(workingPort)\(cleanPath)/NextDocument"
            }
            
            guard let documentURL = URL(string: documentURLString) else {
                scanState = .failed("Invalid document endpoint: \(documentURLString)")
                return
            }
            
            // 4. Download Scanned Data
            scanState = .scanning
            progress = 0.5
            progressMessage = "Scanning in progress... Please wait."
            
            var docRequest = URLRequest(url: documentURL, timeoutInterval: 120.0)
            docRequest.setValue("close", forHTTPHeaderField: "Connection")
            let (docData, docResp) = try await URLSession.shared.data(for: docRequest)
            guard let docHttp = docResp as? HTTPURLResponse, docHttp.statusCode == 200 else {
                scanState = .failed("Failed to retrieve scanned document data.")
                return
            }
            
            // Clean up completed job
            if let deleteURL = URL(string: jobBaseURLString) {
                var delReq = URLRequest(url: deleteURL, timeoutInterval: 5.0)
                delReq.httpMethod = "DELETE"
                delReq.setValue("close", forHTTPHeaderField: "Connection")
                _ = try? await URLSession.shared.data(for: delReq)
            }
            
            progress = 0.9
            progressMessage = "Processing image..."
            
            self.scannedData = docData
            
            if format == .jpeg {
                if let image = NSImage(data: docData) {
                    self.scannedImage = image
                }
            } else if format == .pdf {
                if let pdfDoc = PDFDocument(data: docData), let page = pdfDoc.page(at: 0) {
                    let pageRect = page.bounds(for: .mediaBox)
                    let img = NSImage(size: pageRect.size, flipped: false) { rect in
                        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                        page.draw(with: .mediaBox, to: ctx)
                        return true
                    }
                    self.scannedImage = img
                }
            }
            
            progress = 1.0
            progressMessage = "Scan complete!"
            scanState = .finished
            
        } catch {
            scanState = .failed("Scan error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save and Export
    public func saveToDisk(window: NSWindow? = nil) {
        guard let data = scannedData else { return }
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Scan_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).\(format.fileExtension)"
        savePanel.allowedContentTypes = [format == .pdf ? .pdf : .jpeg]
        
        let response = savePanel.runModal()
        if response == .OK, let targetURL = savePanel.url {
            do {
                try data.write(to: targetURL)
            } catch {
                print("Failed to save: \(error)")
            }
        }
    }
    
    public func openInPreview() {
        guard let data = scannedData else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("Scan_\(UUID().uuidString).\(format.fileExtension)")
        do {
            try data.write(to: tempFile)
            NSWorkspace.shared.open(tempFile)
        } catch {
            print("Failed to open preview: \(error)")
        }
    }
    
    public func copyToClipboard() {
        guard let image = scannedImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}
