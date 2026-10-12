import Cocoa

// MARK: - Model
struct GameOptions {
    var windowMode: Bool = false
    var stretch: Bool = false
    var showFPS: Bool = false
    var crt: Bool = false

    var arguments: [String] {
        var args: [String] = []
        if windowMode { args.append("-W") }
        if stretch { args.append("-S") }
        if showFPS { args.append("-F") }
        if crt { args.append("-C") }
        return args
    }
}

// MARK: - Colors
extension NSColor {
    static let whdBackground = NSColor(red: 0x40/255.0, green: 0x5B/255.0, blue: 0x81/255.0, alpha: 1.0)
    static let whdText = NSColor.white
    static let whdHighlight = NSColor.white
    static let whdBorder = NSColor(red: 0xAA/255.0, green: 0xAA/255.0, blue: 0xAA/255.0, alpha: 1.0)
    static let whdCheck = NSColor(red: 0xAA/255.0, green: 0xAA/255.0, blue: 0xAA/255.0, alpha: 1.0)
}

// MARK: - Text shadow
extension NSShadow {
    static let whdTextShadow: NSShadow = {
        let s = NSShadow()
        s.shadowColor = .black
        s.shadowOffset = NSSize(width: 1, height: -1) // 1px a la derecha y hacia abajo
        s.shadowBlurRadius = 0                         // sin blur
        return s
    }()
}
extension NSTextField {
    /// Reconstruye el texto con sombra usando la fuente, color y alineación actuales.
    func applyHardShadow() {
        let para = NSMutableParagraphStyle()
        para.alignment = alignment

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: textColor ?? NSColor.white,
            .paragraphStyle: para,
            .shadow: NSShadow.whdTextShadow
        ]
        attributedStringValue = NSAttributedString(string: stringValue, attributes: attrs)
    }
}

// MARK: - Option Row
class OptionRow: NSView {
    let label: String
    var isOn: Bool = false
    var onToggle: (() -> Void)?

    private let checkbox: NSImageView
    private let labelText: NSTextField

    init(label: String) {
        self.label = label
        self.checkbox = NSImageView()
        self.labelText = NSTextField(labelWithString: label)
        super.init(frame: NSRect(x: 0, y: 0, width: 256, height: 28))

        // Checkbox
        checkbox.frame = NSRect(x: 0, y: 4, width: 18, height: 18)
        checkbox.imageScaling = .scaleProportionallyUpOrDown
        addSubview(checkbox)

        // Label
        labelText.frame = NSRect(x: 26, y: 5, width: 220, height: 18)
        labelText.font = NSFont(name: "Monaco", size: 13)!
        addSubview(labelText)

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateAppearance() {
        if isOn {
            checkbox.image = NSImage(systemSymbolName: "checkmark.square.fill", accessibilityDescription: "on")
            checkbox.contentTintColor = .whdCheck
            labelText.textColor = .whdHighlight
        } else {
            checkbox.image = NSImage(systemSymbolName: "square.fill", accessibilityDescription: "off")
            checkbox.contentTintColor = .whdCheck
            labelText.textColor = .whdText
        }
        labelText.applyHardShadow()
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        updateAppearance()
        onToggle?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

}

// MARK: - Launcher Window
class LauncherWindowController: NSWindowController, NSWindowDelegate {
    private var options = GameOptions()
    private var rows: [OptionRow] = []
    private var startButton: NSButton!
    private var errorLabel: NSTextField!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hurrican"
        window.isMovableByWindowBackground = true
        window.backgroundColor = .whdBackground
        super.init(window: window)
        window.delegate = self
        setupUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Border
        let borderView = NSView(frame: contentView.bounds)
        borderView.autoresizingMask = [.width, .height]
        borderView.wantsLayer = true
        borderView.layer?.borderColor = NSColor.whdBorder.cgColor
        borderView.layer?.borderWidth = 5
        contentView.addSubview(borderView)

        // Title
        let title = NSTextField(labelWithString: "Hurrican")
        title.font = NSFont(name: "Monaco", size: 24)!
        title.textColor = .whdHighlight
        title.alignment = .center
        title.applyHardShadow()
        title.frame = NSRect(x: 0, y: 350, width: 320, height: 34)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        // Credits
        let credits = NSTextField(labelWithString: "© 1997 Winterworks")
        credits.font = NSFont(name: "Monaco", size: 14)!
        credits.textColor = .whdText
        credits.alignment = .center
        credits.applyHardShadow()
        credits.frame = NSRect(x: 0, y: 320, width: 320, height: 16)
        credits.autoresizingMask = [.width]
        contentView.addSubview(credits)

        let portLabel = NSTextField(labelWithString: "macOS version by @mmoroca & Leo.AI 2026")
        portLabel.font = NSFont(name: "Monaco", size: 10)!
        portLabel.textColor = .whdText
        portLabel.alignment = .center
        portLabel.applyHardShadow()
        portLabel.frame = NSRect(x: 0, y: 300, width: 320, height: 16)
        portLabel.autoresizingMask = [.width]
        contentView.addSubview(portLabel)

        // ⌘Q hint 
        let quitHint = NSTextField(labelWithString: "Press '⌘Q' to quit")
        quitHint.font = NSFont(name: "Monaco", size: 14)!
        quitHint.textColor = .whdText
        quitHint.alignment = .center
        quitHint.applyHardShadow()
        quitHint.frame = NSRect(x: 0, y: 265, width: 320, height: 20)
        quitHint.autoresizingMask = [.width]
        contentView.addSubview(quitHint)

        // Options 
        let optionLabels: [String] = [
            "Run in a window",
            "Run fullscreen stretched",
            "Show the current FPS",
            "Simulate CRT effects"
        ]

        var y: CGFloat = 225
        for label in optionLabels {
            let row = OptionRow(label: label)
            row.frame = NSRect(x: 32, y: y, width: 256, height: 28)
            contentView.addSubview(row)
            rows.append(row)
            y -= 34
        }

        // LAUNCH button
        startButton = NSButton(title: "LAUNCH", target: self, action: #selector(startGame))
        startButton.frame = NSRect(x: 80, y: 60, width: 160, height: 40)
        startButton.bezelColor = NSColor(red: 0xAA/255.0, green: 0xAA/255.0, blue: 0xAA/255.0, alpha: 1.0)
        //startButton.bezelStyle = .rounded
        startButton.attributedTitle = NSAttributedString(
            string: "LAUNCH",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont(name: "Monaco", size: 16)!,
                .shadow: NSShadow.whdTextShadow
            ]
        )
        //startButton.font = NSFont(name: "Monaco", size: 16)!
        //startButton.contentTintColor = .whdText
        startButton.keyEquivalent = "\r"
        contentView.addSubview(startButton)

        // Error label
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont(name: "Monaco", size: 10)!
        errorLabel.textColor = .red
        errorLabel.alignment = .center
        errorLabel.frame = NSRect(x: 10, y: 30, width: 300, height: 20)
        errorLabel.autoresizingMask = [.width]
        contentView.addSubview(errorLabel)
    }   

    @objc private func startGame() {
        options.windowMode = rows[0].isOn
        options.stretch = rows[1].isOn
        options.showFPS = rows[2].isOn
        options.crt = rows[3].isOn

        let binDir = Bundle.main.bundlePath + "/Contents/MacOS"
        let resDir = Bundle.main.bundlePath + "/Contents/Resources"
        let binaryPath = binDir + "/hurrican"

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            errorLabel.stringValue = "Binary not found: \(binaryPath)"
            return
        }

        // Manejar DMG de solo lectura
        var workDir = resDir
        let isWritable = FileManager.default.isWritableFile(atPath: resDir)

        if !isWritable {
            let tmpDir = NSTemporaryDirectory() + "Hurrican_\(UUID().uuidString)"
            let fm = FileManager.default
            try? fm.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
            try? fm.createSymbolicLink(atPath: tmpDir + "/data", withDestinationPath: resDir + "/data")
            try? fm.createSymbolicLink(atPath: tmpDir + "/lang", withDestinationPath: resDir + "/lang")
            workDir = tmpDir
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = options.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            errorLabel.stringValue = "Error: \(error.localizedDescription)"
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(nil)
        return true
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: LauncherWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Hurrican", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu

        windowController = LauncherWindowController()
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Entry Point
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()   