import AppKit
import ApplicationServices
import CoreGraphics

struct AutomationResult {
    let success: Bool
    let message: String
}

final class AppStoreAutomation: @unchecked Sendable {
    static let shared = AppStoreAutomation()
    private init() {}

    func switchAccount(to credentials: AccountCredentials, completion: @escaping @Sendable (AutomationResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard AXIsProcessTrusted() else {
                completion(AutomationResult(success: false, message: "请在系统设置 → 隐私与安全性 → 辅助功能中授权本应用。"))
                return
            }
            let appURL = URL(fileURLWithPath: "/System/Applications/App Store.app")
            NSWorkspace.shared.open(appURL)
            sleep(2)
            guard let app = self.appElement() else {
                completion(AutomationResult(success: false, message: "无法连接到 App Store。"))
                return
            }
            guard self.clickStoreMenuItem(exactTitles: ["Sign Out", "退出登录"], in: app) else {
                completion(AutomationResult(success: false, message: "没有找到 App Store 的退出登录菜单，请先确认 App Store 已打开并已授权辅助功能。"))
                return
            }
            sleep(2)
            _ = self.pressButton(in: app, names: ["Sign Out", "退出登录"])
            sleep(2)
            guard self.clickStoreMenuItem(exactTitles: ["Sign In…", "Sign In", "登录…", "登录"], in: app) else {
                completion(AutomationResult(success: false, message: "已退出当前账号，但没有找到 App Store 的登录菜单。"))
                return
            }
            sleep(2)
            let scope = self.focusedWindow(in: app) ?? self.findElements(in: app, roles: [kAXWindowRole as String]).last ?? app
            let fields = self.findElements(in: scope, roles: [kAXTextFieldRole as String, kAXTextAreaRole as String])
            let secureFields = fields.filter { self.attribute($0, kAXSubroleAttribute as String) == kAXSecureTextFieldSubrole as String }
            let regularFields = fields.filter { self.attribute($0, kAXSubroleAttribute as String) != kAXSecureTextFieldSubrole as String }

            if fields.count == 1 {
                // Handle the single-field flow before the generic password branch.
                // A secure field here is a password confirmation for the remembered account.
                let subrole = self.attribute(fields[0], kAXSubroleAttribute as String)
                guard subrole != kAXSecureTextFieldSubrole as String else {
                    completion(AutomationResult(success: false, message: "App Store 只显示了当前账号的密码框，已停止以避免误填目标密码。"))
                    return
                }
                AXUIElementSetAttributeValue(fields[0], kAXValueAttribute as CFString, credentials.email as CFTypeRef)
                guard self.pressButton(in: scope, names: ["Sign In", "登录", "Continue", "继续"]) || self.pressDefaultButton(in: scope) else {
                    completion(AutomationResult(success: false, message: "账号已填入，但未找到下一步按钮。"))
                    return
                }
                sleep(1)
                for _ in 0..<12 {
                    if self.fillPasswordWithSystemEvents(credentials.password) {
                        completion(AutomationResult(success: true, message: "账号和密码已提交；如出现双重认证，请在 App Store 中完成验证。"))
                        return
                    }
                    usleep(400_000)
                }

                if self.typePasswordIntoFocusedApp(credentials.password) {
                    completion(AutomationResult(success: true, message: "密码已提交；如出现双重认证，请在 App Store 中完成验证。"))
                    return
                }

                let nextScope = self.focusedWindow(in: app) ?? self.findElements(in: app, roles: [kAXWindowRole as String]).last ?? app
                let nextFields = self.findElements(in: nextScope, roles: [kAXTextFieldRole as String, kAXTextAreaRole as String])
                guard let nextPassword = nextFields.first(where: { self.attribute($0, kAXSubroleAttribute as String) == kAXSecureTextFieldSubrole as String }) else {
                    completion(AutomationResult(success: false, message: "账号已提交，但没有找到后续密码输入框，请手动继续。"))
                    return
                }
                AXUIElementSetAttributeValue(nextPassword, kAXValueAttribute as CFString, credentials.password as CFTypeRef)
                guard self.pressButton(in: nextScope, names: ["Sign In", "登录", "Continue", "继续"]) || self.pressDefaultButton(in: nextScope) else {
                    completion(AutomationResult(success: false, message: "密码已填入，但未找到登录按钮，请手动完成登录。"))
                    return
                }
            } else if let passwordField = secureFields.first {
                if let emailField = regularFields.first {
                    AXUIElementSetAttributeValue(emailField, kAXValueAttribute as CFString, credentials.email as CFTypeRef)
                }
                AXUIElementSetAttributeValue(passwordField, kAXValueAttribute as CFString, credentials.password as CFTypeRef)
            } else if fields.count >= 2 {
                AXUIElementSetAttributeValue(fields[0], kAXValueAttribute as CFString, credentials.email as CFTypeRef)
                AXUIElementSetAttributeValue(fields[1], kAXValueAttribute as CFString, credentials.password as CFTypeRef)
            } else {
                completion(AutomationResult(success: false, message: "已打开登录界面，但未找到输入框，请手动完成登录。"))
                return
            }
            guard self.pressButton(in: scope, names: ["Sign In", "登录", "Continue", "继续"]) || self.pressDefaultButton(in: scope) else {
                completion(AutomationResult(success: false, message: "密码已填入，但未找到登录按钮，请在 App Store 登录窗口点击“登录”。"))
                return
            }
            completion(AutomationResult(success: true, message: "账号信息已提交；如出现双重认证，请在 App Store 中完成验证。"))
        }
    }

    private func appElement() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.AppStore").first else { return nil }
        app.activate()
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    private func focusedWindow(in app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value else { return nil }
        return value as! AXUIElement
    }

    private func clickStoreMenuItem(exactTitles titles: [String], in app: AXUIElement) -> Bool {
        // System Events exposes App Store's menu hierarchy more reliably than the raw AX tree.
        for menuTitle in ["Store", "商店"] {
            for itemTitle in titles {
                if runMenuScript(menuTitle: menuTitle, itemTitle: itemTitle) { return true }
            }
        }

        // Fallback for systems where System Events is unavailable.
        let menuBars = findElements(in: app, roles: [kAXMenuBarRole as String])
        guard let menuBar = menuBars.first else { return false }
        let menuItems = findElements(in: menuBar, roles: [kAXMenuBarItemRole as String])
        guard let store = menuItems.first(where: { ["Store", "商店"].contains(attribute($0, kAXTitleAttribute as String) ?? "") }) else {
            return false
        }
        guard AXUIElementPerformAction(store, kAXPressAction as CFString) == .success else { return false }
        usleep(300_000)

        // Only inspect the menu attached to the Store menu-bar item. Never search the global menu tree.
        var menuValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(store, "AXMenu" as CFString, &menuValue) == .success,
              let menuValue else { return false }
        let menu = menuValue as! AXUIElement
        let items = findElements(in: menu, roles: [kAXMenuItemRole as String])
        guard let item = items.first(where: { titles.contains(attribute($0, kAXTitleAttribute as String) ?? "") }) else { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    private func runMenuScript(menuTitle: String, itemTitle: String) -> Bool {
        let menu = escapeAppleScriptString(menuTitle)
        let item = escapeAppleScriptString(itemTitle)
        let source = """
        tell application "System Events"
            tell process "App Store"
                if exists menu bar item "\(menu)" of menu bar 1 then
                    click menu item "\(item)" of menu 1 of menu bar item "\(menu)" of menu bar 1
                    return true
                end if
            end tell
        end tell
        return false
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil && result?.booleanValue == true
    }

    private func escapeAppleScriptString(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func fillPasswordWithSystemEvents(_ password: String) -> Bool {
        let escapedPassword = escapeAppleScriptString(password)
        let source = """
        tell application "System Events"
            tell process "App Store"
                repeat with w in windows
                    set allTextFields to every text field of entire contents of w
                    if (count of allTextFields) > 1 then
                        set value of last item of allTextFields to "\(escapedPassword)"
                        repeat with b in (every button of entire contents of w)
                            set buttonName to name of b
                            if buttonName is "登录" or buttonName is "Sign In" or buttonName is "继续" or buttonName is "Continue" then
                                click b
                                return true
                            end if
                        end repeat
                    else
                        set allSecureFields to every secure text field of entire contents of w
                        if (count of allSecureFields) > 0 then
                            set value of first item of allSecureFields to "\(escapedPassword)"
                        else
                            set allSecureFields to {}
                        end if
                        repeat with b in (every button of entire contents of w)
                            set buttonName to name of b
                            if buttonName is "登录" or buttonName is "Sign In" or buttonName is "继续" or buttonName is "Continue" then
                                click b
                                return true
                            end if
                        end repeat
                    end if
                end repeat
            end tell
        end tell
        return false
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil && result?.booleanValue == true
    }

    private func typePasswordIntoFocusedApp(_ password: String) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.AppStore" else { return false }
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        var unicode = Array(password.utf16)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { return false }
        keyDown.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: &unicode)
        keyDown.post(tap: .cghidEventTap)
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
        usleep(200_000)
        if let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true) {
            enterDown.post(tap: .cghidEventTap)
        }
        if let enterUp = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false) {
            enterUp.post(tap: .cghidEventTap)
        }
        return true
    }

    private func pressButton(in app: AXUIElement, names: [String]) -> Bool {
        let buttons = findElements(in: app, roles: [kAXButtonRole as String])
        if let button = buttons.first(where: { names.contains(attribute($0, kAXTitleAttribute as String) ?? "") }) {
            return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
        }
        return false
    }

    private func pressDefaultButton(in window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXDefaultButtonAttribute as CFString, &value) == .success,
              let value else { return false }
        let button = value as! AXUIElement
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    private func findElements(in root: AXUIElement, roles: [String]) -> [AXUIElement] {
        var found: [AXUIElement] = []
        walk(root, roles: Set(roles), found: &found, depth: 0)
        return found
    }

    private func walk(_ element: AXUIElement, roles: Set<String>, found: inout [AXUIElement], depth: Int) {
        guard depth < 12 else { return }
        if let role = attribute(element, kAXRoleAttribute as String), roles.contains(role) { found.append(element) }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return }
        for child in children { walk(child, roles: roles, found: &found, depth: depth + 1) }
    }

    private func attribute(_ element: AXUIElement, _ key: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
