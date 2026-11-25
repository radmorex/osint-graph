// OSINT Graph — нативная оболочка macOS вокруг index.html (WKWebView).
// Данные: ~/Library/Application Support/OSINT Graph/data.json (+ ежедневные копии в backups/).
import Cocoa
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!

    let dataDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/OSINT Graph", isDirectory: true)
    var dataFile: URL { dataDir.appendingPathComponent("data.json") }
    var backupDir: URL { dataDir.appendingPathComponent("backups", isDirectory: true) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        buildMenu()

        let uc = WKUserContentController()
        uc.add(self, name: "native")
        // Передаём сохранённые данные в страницу до запуска её скриптов (только если это валидный JSON).
        var initial = "null"
        if let d = try? Data(contentsOf: dataFile),
           (try? JSONSerialization.jsonObject(with: d)) != nil,
           let s = String(data: d, encoding: .utf8) { initial = s }
        uc.addUserScript(WKUserScript(source: "window.__NATIVE_DATA__ = \(initial);",
                                      injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = uc
        web = WKWebView(frame: .zero, configuration: cfg)
        web.uiDelegate = self
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "OSINT Graph"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1)
        window.minSize = NSSize(width: 700, height: 480)
        window.contentView = web
        window.center()
        window.setFrameAutosaveName("OSINTGraphMain")
        window.makeKeyAndOrderFront(nil)

        if let html = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: меню (нужно, чтобы ⌘C / ⌘V / ⌘Z / ⌘Q работали)
    func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "О программе OSINT Graph", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Открыть папку с данными", action: #selector(openDataFolder), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Скрыть OSINT Graph", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Правка")
        edit.addItem(withTitle: "Отменить", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Вернуть", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Вырезать", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Копировать", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Вставить", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Выделить всё", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let view = NSMenu(title: "Вид")
        view.addItem(withTitle: "Во весь экран", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f").keyEquivalentModifierMask = [.command, .control]
        viewItem.submenu = view

        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "Окно")
        win.addItem(withTitle: "Свернуть", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "Закрыть", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = win
        NSApp.windowsMenu = win

        NSApp.mainMenu = main
    }

    @objc func openDataFolder() { NSWorkspace.shared.open(dataDir) }

    // MARK: сообщения из страницы
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "save":
            guard let s = body["data"] as? String, let d = s.data(using: .utf8) else { return }
            do { try d.write(to: dataFile, options: .atomic) } catch { showAlert("Не удалось сохранить данные: \(error.localizedDescription)") }
            dailyBackup(d)
        case "open":
            if let s = body["url"] as? String, let u = URL(string: s),
               let scheme = u.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                NSWorkspace.shared.open(u)
            }
        case "export":
            let name = (body["name"] as? String) ?? "export"
            var data: Data?
            if let t = body["text"] as? String { data = t.data(using: .utf8) }
            else if let b = body["base64"] as? String { data = Data(base64Encoded: b) }
            guard let out = data else { return }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = name
            panel.canCreateDirectories = true
            panel.beginSheetModal(for: window) { resp in
                guard resp == .OK, let url = panel.url else { return }
                do { try out.write(to: url, options: .atomic) } catch { self.showAlert("Не удалось сохранить файл: \(error.localizedDescription)") }
            }
        default: break
        }
    }

    func dailyBackup(_ d: Data) {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let target = backupDir.appendingPathComponent("data-\(f.string(from: Date())).json")
        if !FileManager.default.fileExists(atPath: target.path) { try? d.write(to: target, options: .atomic) }
        // оставляем 30 последних копий
        if let files = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
            .filter({ $0.lastPathComponent.hasPrefix("data-") }).sorted(by: { $0.lastPathComponent > $1.lastPathComponent }),
           files.count > 30 {
            for old in files.dropFirst(30) { try? FileManager.default.removeItem(at: old) }
        }
    }

    func showAlert(_ text: String) {
        let a = NSAlert(); a.messageText = text; a.runModal()
    }

    // MARK: alert / confirm / prompt / выбор файла
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        showAlert(message); completionHandler()
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = NSAlert(); a.messageText = message
        a.addButton(withTitle: "OK"); a.addButton(withTitle: "Отмена")
        completionHandler(a.runModal() == .alertFirstButtonReturn)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = NSAlert(); a.messageText = prompt
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        tf.stringValue = defaultText ?? ""
        a.accessoryView = tf
        a.addButton(withTitle: "OK"); a.addButton(withTitle: "Отмена")
        a.window.initialFirstResponder = tf
        completionHandler(a.runModal() == .alertFirstButtonReturn ? tf.stringValue : nil)
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false; p.canChooseDirectories = false; p.canChooseFiles = true
        p.beginSheetModal(for: window) { resp in completionHandler(resp == .OK ? p.urls : nil) }
    }
    // ссылки, открывающие новое окно, — в системный браузер
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = navigationAction.request.url, let s = u.scheme?.lowercased(), s == "http" || s == "https" { NSWorkspace.shared.open(u) }
        return nil
    }
    // не даём странице уйти куда-то кроме самой программы
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let u = navigationAction.request.url else { return decisionHandler(.cancel) }
        if u.isFileURL || u.scheme == "about" || u.scheme == "blob" || u.scheme == "data" { return decisionHandler(.allow) }
        if let s = u.scheme?.lowercased(), s == "http" || s == "https" { NSWorkspace.shared.open(u) }
        decisionHandler(.cancel)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
