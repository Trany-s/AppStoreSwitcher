import SwiftUI
import AppKit
import LocalAuthentication

struct ContentView: View {
    @ObservedObject var store: AccountStore
    @State private var showingAdd = false
    @State private var editingAccount: StoredAccount?
    @State private var busy = false
    @State private var status = "就绪"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("App Store 账号")
                        .font(.system(size: 24, weight: .semibold))
                    Text("安全保存并快速切换你的 Apple 账号")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingAdd = true } label: {
                    Label("添加账号", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 20)

            if store.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.crop.square.stack")
                        .font(.system(size: 34))
                        .foregroundStyle(.tint)
                    Text("还没有保存账号")
                        .font(.headline)
                    Text("添加一个 App Store 账号，之后可以一键切换登录。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("添加第一个账号") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 190)
                .background(Color(nsColor: .underPageBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.accounts) { account in
                            AccountRow(account: account, busy: busy, onSwitch: { switchTo(account) }, onEdit: { editingAccount = account }, onDelete: { store.remove(account) })
                        }
                    }
                }
                .frame(maxHeight: 285)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(busy ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 18)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("首次使用需允许辅助功能和自动化权限；双重认证仍需手动完成。")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAdd) { AddAccountView(store: store) }
        .sheet(item: $editingAccount) { account in EditAccountView(store: store, account: account) }
        .alert("操作提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("确定") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private func switchTo(_ account: StoredAccount) {
        guard let credentials = store.credentials(for: account) else { return }
        busy = true
        status = "正在打开 App Store…"
        AppStoreAutomation.shared.switchAccount(to: credentials) { result in
            DispatchQueue.main.async {
                busy = false
                status = result.message
            }
        }
    }
}

private struct AccountRow: View {
    let account: StoredAccount
    let busy: Bool
    let onSwitch: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name).font(.headline)
                Text(account.email).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button("切换") { onSwitch() }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(busy)
            Menu {
                Button("编辑账号", action: onEdit)
                Divider()
                Button("删除账号", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(14)
        .background(Color(nsColor: .underPageBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct EditAccountView: View {
    @ObservedObject var store: AccountStore
    let account: StoredAccount
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var email: String
    @State private var password: String
    @State private var showingPassword = false
    @State private var authenticating = false

    init(store: AccountStore, account: StoredAccount) {
        self.store = store
        self.account = account
        let credentials = store.credentials(for: account)
        _name = State(initialValue: account.name)
        _email = State(initialValue: credentials?.email ?? account.email)
        _password = State(initialValue: credentials?.password ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("编辑账号").font(.headline)
            TextField("备注名称", text: $name)
            TextField("Apple 账号", text: $email)
            HStack {
                if showingPassword {
                    TextField("密码", text: $password)
                } else {
                    SecureField("密码", text: $password)
                }
                Button(authenticating ? "验证中…" : (showingPassword ? "隐藏" : "查看密码")) {
                    authenticateAndTogglePassword()
                }
                .disabled(authenticating)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    store.update(account, name: name, email: email, password: password)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(email.isEmpty || password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func authenticateAndTogglePassword() {
        if showingPassword {
            showingPassword = false
            return
        }
        authenticating = true
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "验证身份后查看 App Store 密码") { success, _ in
            DispatchQueue.main.async {
                authenticating = false
                if success { showingPassword = true }
            }
        }
    }
}

private struct AddAccountView: View {
    @ObservedObject var store: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加账号").font(.headline)
            TextField("备注名称（可选）", text: $name)
            TextField("Apple 账号", text: $email)
            SecureField("密码", text: $password)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    store.add(name: name, email: email, password: password)
                    dismiss()
                }.keyboardShortcut(.defaultAction).disabled(email.isEmpty || password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
