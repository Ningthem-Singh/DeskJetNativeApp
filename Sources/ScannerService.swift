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
        progressMessage = "Connecting to scanner (\(host):\(port))..."
        
        // 1. Check Scanner Readiness
        let statusURL = URL(string: "http://\(host):\(port)/eSCL/ScannerStatus")!
        do {
            let statusReq = URLRequest(url: statusURL, timeoutInterval: 8.0)
            let (statusData, statusResp) = try await URLSession.shared.data(for: statusReq)
            if let http = statusResp as? HTTPURLResponse, http.statusCode == 200 {
                let statusStr = String(data: statusData, encoding: .utf8) ?? ""
                if statusStr.contains("<pwg:State>Processing</pwg:State>") || statusStr.contains("<pwg:State>Testing</pwg:State>") {
                    scanState = .failed("Scanner is currently busy. Please wait a moment and try again.")
                    return
                }
            }
        } catch {
            scanState = .failed("Could not connect to scanner at \(host):\(port): \(error.localizedDescription)")
            return
        }
        
        progress = 0.25
        progressMessage = "Sending scan job parameters..."
        
        // 2. Build eSCL Scan Job Request
        let jobsURL = URL(string: "http://\(host):\(port)/eSCL/ScanJobs")!
        var request = URLRequest(url: jobsURL, timeoutInterval: 15.0)
        request.httpMethod = "POST"
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("", forHTTPHeaderField: "Expect") // Prevent HP embedded server Expect: 100-continue hang
        
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
            if locationHeader.hasPrefix("http") {
                documentURLString = "\(locationHeader)/NextDocument"
            } else {
                let cleanPath = locationHeader.hasPrefix("/") ? locationHeader : "/\(locationHeader)"
                documentURLString = "http://\(host):\(port)\(cleanPath)/NextDocument"
            }
            
            guard let documentURL = URL(string: documentURLString) else {
                scanState = .failed("Invalid document endpoint: \(documentURLString)")
                return
            }
            
            // 4. Download Scanned Data
            scanState = .scanning
            progress = 0.5
            progressMessage = "Scanning in progress... Please wait."
            
            let docRequest = URLRequest(url: documentURL, timeoutInterval: 60.0)
            let (docData, docResp) = try await URLSession.shared.data(for: docRequest)
            guard let docHttp = docResp as? HTTPURLResponse, docHttp.statusCode == 200 else {
                scanState = .failed("Failed to retrieve scanned document data.")
                return
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
