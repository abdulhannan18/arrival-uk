import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

struct AdPrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preferences: AdPreferencesStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Ad Experience") {
                    Text("Ads are delayed by warm-up and interaction rules to avoid disruption.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if preferences.needsInitialDisclosure {
                        Text("By continuing, you acknowledge that ads and anonymous usage metrics help keep the app free.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if AdRuntime.isAdsEnabledForCurrentBuild {
                        Toggle(
                            "Allow personalized ads",
                            isOn: Binding(
                                get: { preferences.wantsPersonalizedAds },
                                set: { newValue in
                                    Task { @MainActor in
                                        await preferences.setPersonalizedAdsRequested(newValue)
                                        AdRuntime.updateConsentConfiguration()
                                    }
                                }
                            )
                        )
                    } else {
                        Text("Ads are not enabled in this build, so tracking permission is never requested.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Tracking status: \(preferences.trackingStatusDescription)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Reset ad preferences") {
                        preferences.resetPrivacyChoices()
                        AdRuntime.updateConsentConfiguration()
                    }
                    .font(.footnote.weight(.semibold))
                }

                Section("Safety Filters") {
                    Text("Blocked categories")
                        .font(.subheadline.weight(.semibold))
                    Text(AdContentRules.blockedCategorySummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data disclosure") {
                    Text("Collected on device: profile details, task completion state, and ad preference settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Potential third parties (if enabled): Google Sign-In and Google AdMob.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Legal and support") {
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.privacyPolicyURL) {
                        Link("Open privacy policy", destination: url)
                    }
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.termsOfServiceURL) {
                        Link("Open terms of service", destination: url)
                    }
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.dataDeletionURL) {
                        Link("Request data deletion", destination: url)
                    }
                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.supportURL) {
                        Link("Open support center", destination: url)
                    }
                    if let supportEmailURL = AppConfig.legal.supportEmailURL {
                        Link("Email support", destination: supportEmailURL)
                    }
                }
            }
            .navigationTitle("Ad & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { close() }
                }
            }
        }
    }

    private func close() {
        preferences.updateDisclosureAccepted()
        AdRuntime.updateConsentConfiguration()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

struct HelpSheet: View {
    var onOpenAdPrivacy: () -> Void
    var onOpenEmergencyContacts: () -> Void
    var onOpenPrivacy: () -> Void
    var onClose: (() -> Void)? = nil

    private var crashTestEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ARRIVAL_CRASH_TEST"] == "1"
        #else
        false
        #endif
    }

    @State private var showCopiedDiagnostics = false
    @State private var isSubmittingSupportTicket = false
    @State private var supportSubmissionAlertTitle = ""
    @State private var supportSubmissionAlertMessage = ""
    @State private var showSupportSubmissionAlert = false
    @State private var showSupportReplySheet = false
    @State private var latestSupportTicketID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Help")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(HelpFastButtonStyle())
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceM) {
                    helpRow(
                        title: "Profile and sign in",
                        subtitle: "Manage Apple/Google login and student details in profile setup.",
                        icon: "person.crop.circle"
                    )

                    helpRow(
                        title: "Task details and official sources",
                        subtitle: "Open a task and use \"Open Official Guidance\" for verified links.",
                        icon: "doc.text.magnifyingglass"
                    )

                    helpRow(
                        title: "Ads and privacy controls",
                        subtitle: "Manage personalization and tracking settings.",
                        icon: "hand.raised"
                    ) {
                        onOpenAdPrivacy()
                    }

                    helpRow(
                        title: "Emergency contacts",
                        subtitle: "Call 999, NHS 111, and other key support lines quickly.",
                        icon: "phone.badge.checkmark"
                    ) {
                        onOpenEmergencyContacts()
                    }

                    helpRow(
                        title: "Privacy policy",
                        subtitle: "Review policy details and data handling.",
                        icon: "lock.shield"
                    ) {
                        onOpenPrivacy()
                    }

                    helpRow(
                        title: "Copy diagnostics",
                        subtitle: "Copies app version and recent launch breadcrumbs for support.",
                        icon: "doc.on.doc"
                    ) {
                        copyDiagnosticsToClipboard()
                    }

                    Button {
                        Task { await submitDiagnosticsSupportTicket() }
                    } label: {
                        helpRowContent(
                            title: isSubmittingSupportTicket ? "Submitting support ticket..." : "Submit diagnostics ticket",
                            subtitle: "Sends diagnostics to support from inside the app.",
                            icon: "paperplane",
                            showsChevron: false
                        )
                    }
                    .buttonStyle(HelpFastButtonStyle())
                    .disabled(isSubmittingSupportTicket)

                    helpRow(
                        title: "Reply to support ticket",
                        subtitle: latestSupportTicketID.isEmpty
                            ? "Send a reply using your ticket ID."
                            : "Continue ticket \(latestSupportTicketID).",
                        icon: "bubble.left.and.bubble.right"
                    ) {
                        showSupportReplySheet = true
                    }

                    if crashTestEnabled {
                        helpRow(
                            title: "Send test crash (Crashlytics)",
                            subtitle: "Crashes the app to verify crash reporting in this build.",
                            icon: "ant.fill"
                        ) {
                            triggerCrashTest()
                        }
                    }

                    if let supportURL = ExternalURLPolicy.normalizedURL(from: "https://www.gov.uk/ukvi") {
                        Link(destination: supportURL) {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.linkText)
                                Text("Open UKVI support website")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.linkText)
                                Spacer()
                            }
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Theme.terracotta50)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .stroke(Theme.terracotta200, lineWidth: 1)
                            )
                        }
                        .buttonStyle(HelpFastButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.vertical, Theme.spaceM)
            }
        }
        .background(Theme.card)
        .onAppear {
            refreshLatestSupportTicketID()
        }
        .alert("Copied", isPresented: $showCopiedDiagnostics) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Diagnostics copied to clipboard. Paste into your support message.")
        }
        .alert(supportSubmissionAlertTitle, isPresented: $showSupportSubmissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(supportSubmissionAlertMessage)
        }
        .sheet(isPresented: $showSupportReplySheet) {
            SupportReplySheet(initialTicketID: latestSupportTicketID) { ticketID, messageID in
                latestSupportTicketID = ticketID
                supportSubmissionAlertTitle = "Reply sent"
                supportSubmissionAlertMessage = "Message \(messageID) was added to ticket \(ticketID)."
                showSupportSubmissionAlert = true
            }
        }
    }

    @ViewBuilder
    private func helpRow(
        title: String,
        subtitle: String,
        icon: String,
        action: (() -> Void)? = nil
    ) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    helpRowContent(title: title, subtitle: subtitle, icon: icon, showsChevron: true)
                }
                .buttonStyle(HelpFastButtonStyle())
            } else {
                helpRowContent(title: title, subtitle: subtitle, icon: icon, showsChevron: false)
            }
        }
    }

    private func helpRowContent(
        title: String,
        subtitle: String,
        icon: String,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.spaceS) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 2)
            }
        }
        .padding(Theme.spaceM)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .fill(Theme.gray50)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func close() {
        onClose?()
    }

    private func triggerCrashTest() {
        #if DEBUG
        CrashReporter.log("intentional_crash_test_requested", level: .critical)

        #if canImport(FirebaseCrashlytics)
        if FirebaseApp.app() != nil {
            Crashlytics.crashlytics().log("intentional_crash_test_triggered")
        }
        #endif

        fatalError("Intentional crash test (ARRIVAL_CRASH_TEST=1)")
        #else
        CrashReporter.log("intentional_crash_test_blocked_in_release", level: .warning)
        #endif
    }

    private func copyDiagnosticsToClipboard() {
        let lines = diagnosticsReportLines()

        #if canImport(UIKit)
        UIPasteboard.general.string = lines.joined(separator: "\n")
        #endif

        Haptics.successIfAllowed()
        showCopiedDiagnostics = true
    }

    private func diagnosticsReportLines() -> [String] {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let environment = AppConfig.environment.rawValue
        let categories = ContentStore.shared.categories
        let totalTasks = categories.flatMap(\.tasks).count
        let completedTasks = categories.flatMap(\.tasks).filter(\.isComplete).count
        let breadcrumbs = LaunchMetrics.recentBreadcrumbs()

        #if canImport(UIKit)
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        #else
        let deviceModel = "unknown"
        let systemVersion = "unknown"
        #endif

        var lines: [String] = []
        lines.append("Arrival UK diagnostics")
        lines.append("app_version: \(version) (\(build))")
        lines.append("env: \(environment)")
        lines.append("device: \(deviceModel)")
        lines.append("ios: \(systemVersion)")
        lines.append("tasks: \(completedTasks)/\(totalTasks)")
        lines.append("")
        lines.append("breadcrumbs:")
        lines.append(contentsOf: breadcrumbs)
        return lines
    }

    private func submitDiagnosticsSupportTicket() async {
        guard !isSubmittingSupportTicket else { return }

        guard let authManager = AuthenticationManager.shared else {
            supportSubmissionAlertTitle = "Support unavailable"
            supportSubmissionAlertMessage = "Sign in services are not configured in this build."
            showSupportSubmissionAlert = true
            return
        }

        guard authManager.isAuthenticated else {
            supportSubmissionAlertTitle = "Sign in required"
            supportSubmissionAlertMessage = "Please sign in before submitting an in-app support ticket."
            showSupportSubmissionAlert = true
            return
        }

        isSubmittingSupportTicket = true
        defer { isSubmittingSupportTicket = false }

        let diagnostics = diagnosticsReportLines().joined(separator: "\n")
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

        do {
            let ticketID = try await authManager.createSupportTicket(
                subject: "iOS diagnostics (\(appVersion))",
                message: diagnostics,
                category: "app_diagnostics",
                priority: "normal",
                metadata: [
                    "source": "help_sheet",
                    "type": "diagnostics",
                ]
            )

            Haptics.successIfAllowed()
            latestSupportTicketID = ticketID
            supportSubmissionAlertTitle = "Ticket submitted"
            supportSubmissionAlertMessage = "Support ticket \(ticketID) has been created."
            showSupportSubmissionAlert = true
        } catch {
            CrashReporter.record(error: error, context: "support_submit_diagnostics_ticket")
            supportSubmissionAlertTitle = "Submission failed"
            supportSubmissionAlertMessage = "Could not submit your support ticket right now. Please try again."
            showSupportSubmissionAlert = true
        }
    }

    private func refreshLatestSupportTicketID() {
        guard let authManager = AuthenticationManager.shared,
              authManager.isAuthenticated
        else {
            latestSupportTicketID = ""
            return
        }
        latestSupportTicketID = authManager.latestSupportTicketID()
    }
}

private struct SupportReplySheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialTicketID: String
    var onSuccess: (_ ticketID: String, _ messageID: String) -> Void

    @State private var ticketID: String
    @State private var replyMessage = ""
    @State private var isSubmitting = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showErrorAlert = false

    init(
        initialTicketID: String,
        onSuccess: @escaping (_ ticketID: String, _ messageID: String) -> Void
    ) {
        self.initialTicketID = initialTicketID
        self.onSuccess = onSuccess
        _ticketID = State(initialValue: initialTicketID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ticket") {
                    TextField("Ticket ID", text: $ticketID)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                }

                Section("Reply") {
                    TextEditor(text: $replyMessage)
                        .frame(minHeight: 140)
                    Text("Max 4000 characters")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Support Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Sending..." : "Send") {
                        Task { await sendReply() }
                    }
                    .disabled(isSubmitting || !canSubmit)
                }
            }
            .alert(errorTitle, isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canSubmit: Bool {
        let normalizedTicketID = ticketID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMessage = replyMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalizedTicketID.isEmpty && !normalizedMessage.isEmpty
    }

    private func sendReply() async {
        guard !isSubmitting else { return }

        guard let authManager = AuthenticationManager.shared else {
            presentError(title: "Support unavailable", message: "Sign in services are not configured in this build.")
            return
        }

        guard authManager.isAuthenticated else {
            presentError(title: "Sign in required", message: "Please sign in before sending a support reply.")
            return
        }

        let normalizedTicketID = ticketID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMessage = replyMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let messageID = try await authManager.addSupportTicketMessage(
                ticketId: normalizedTicketID,
                message: normalizedMessage,
                metadata: [
                    "source": "help_sheet_reply",
                ]
            )
            Haptics.successIfAllowed()
            onSuccess(normalizedTicketID, messageID)
            dismiss()
        } catch {
            CrashReporter.record(error: error, context: "support_send_ticket_reply")
            presentError(title: "Reply failed", message: "Could not send your message. Please try again.")
        }
    }

    private func presentError(title: String, message: String) {
        errorTitle = title
        errorMessage = message
        showErrorAlert = true
    }
}

struct PrivacyInfoSheet: View {
    var onClose: (() -> Void)? = nil

    @State private var exportFileURL: URL?
    @State private var isPresentingExportShareSheet = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showEraseConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Privacy")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(HelpFastButtonStyle())
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceM) {
                    Text("We only show safe ad categories and block sensitive topics by default. You can control personalized ads from Ad & Privacy settings.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data we store locally")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("• Student profile details for checklist personalization")
                        Text("• Task completion progress and custom tasks")
                        Text("• Notification and ad-consent preferences")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Third-party services (if enabled)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("• Google Sign-In for authentication")
                        Text("• Google AdMob for advertising")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                    if let url = ExternalURLPolicy.normalizedURL(from: AdLegal.privacyPolicyURL) {
                        Link(destination: url) {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Open Privacy Policy")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Theme.inverseText)
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Theme.primaryButtonBackground)
                            )
                        }
                        .buttonStyle(HelpFastButtonStyle())
                    }

                    if let termsURL = ExternalURLPolicy.normalizedURL(from: AdLegal.termsOfServiceURL) {
                        Link(destination: termsURL) {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Open Terms of Service")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Theme.linkText)
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Theme.terracotta50)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .stroke(Theme.terracotta200, lineWidth: 1)
                            )
                        }
                        .buttonStyle(HelpFastButtonStyle())
                    }

                    if let deletionURL = ExternalURLPolicy.normalizedURL(from: AdLegal.dataDeletionURL) {
                        Link("Request data deletion", destination: deletionURL)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.linkText)
                    }

                    if let supportEmailURL = AppConfig.legal.supportEmailURL {
                        Link("Email support", destination: supportEmailURL)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.linkText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your data")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)

                        Button {
                            exportLocalData()
                        } label: {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Export my local data")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            .foregroundStyle(Theme.linkText)
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Theme.gray50)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(HelpFastButtonStyle())
                        .accessibilityHint("Creates a JSON export and opens the share sheet")

                        Button(role: .destructive) {
                            showEraseConfirmation = true
                        } label: {
                            HStack(spacing: Theme.spaceS) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Erase local data")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                            }
                            .foregroundStyle(.red)
                            .padding(Theme.spaceM)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .fill(Color.red.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(HelpFastButtonStyle())
                        .accessibilityHint("Signs out and removes profile, progress, and preferences from this device")
                    }
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.vertical, Theme.spaceM)
            }
        }
        .background(Theme.card)
        .sheet(isPresented: $isPresentingExportShareSheet, onDismiss: cleanupExportFile) {
            #if canImport(UIKit)
            if let exportFileURL {
                ShareSheet(activityItems: [exportFileURL])
                    .ignoresSafeArea()
            }
            #else
            EmptyView()
            #endif
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .alert("Erase local data?", isPresented: $showEraseConfirmation) {
            Button("Erase", role: .destructive) {
                eraseLocalData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your profile, checklist progress, and preferences from this device.")
        }
    }

    private func close() {
        onClose?()
    }

    private func exportLocalData() {
        Task { @MainActor in
            do {
                let export = LocalDataExportBuilder.build()
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(export)
                let url = try LocalDataExportBuilder.writeExportFile(data: data)
                exportFileURL = url
                isPresentingExportShareSheet = true
                Haptics.successIfAllowed()
            } catch {
                exportErrorMessage = "Could not export data. Please try again."
                showExportError = true
                CrashReporter.record(error: error, context: "local_data_export")
            }
        }
    }

    private func cleanupExportFile() {
        guard let exportFileURL else { return }
        try? FileManager.default.removeItem(at: exportFileURL)
        self.exportFileURL = nil
    }

    private func eraseLocalData() {
        StudentProfileStore.shared.logout(contentStore: .shared)
        NotificationManager.shared.cancelAllReminders()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: StorageKey.pushInstallationID.rawValue)
        defaults.removeObject(forKey: StorageKey.pushPendingFCMToken.rawValue)
        let supportPrefix = StorageKey.supportLatestTicketIDPrefix.rawValue
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(supportPrefix) {
            defaults.removeObject(forKey: key)
        }
        LaunchMetrics.clearBreadcrumbs()
        Task { @MainActor in
            AdPreferencesStore.shared.resetPrivacyChoices()
        }
        Haptics.successIfAllowed()
    }
}

private struct HelpFastButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var prefersReducedMotion: Bool {
        reduceMotion || PerformanceProfile.prefersConservativeVisuals
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                configuration.isPressed
                    ? Motion.pressDown(prefersReducedMotion: prefersReducedMotion)
                    : Motion.pressUp(prefersReducedMotion: prefersReducedMotion),
                value: configuration.isPressed
            )
    }
}

// MARK: - Share + Export

#if canImport(UIKit)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct LocalDataExport: Codable {
    struct AppMetadata: Codable {
        let version: String
        let build: String
        let environment: String
    }

    struct ProfileData: Codable {
        let authProvider: StudentAuthProvider
        let fullName: String
        let email: String
        let selectedUniversity: String
        let courseName: String
        let city: String
        let studyLevel: StudyLevel
        let arrivalDate: Date
        let hasCompletedSetup: Bool
    }

    struct ProgressData: Codable {
        struct CustomTask: Codable {
            let id: String
            let title: String
            let detail: String?
            let isComplete: Bool
            let urgency: TaskUrgency
            let timing: TaskTiming
            let priority: TaskPriority
        }

        let totalTasks: Int
        let completedTasks: Int
        let completedTaskIDs: [String]
        let customTasksByCategory: [String: [CustomTask]]
    }

    struct AdPreferencesData: Codable {
        let wantsPersonalizedAds: Bool
        let trackingAuthorizationState: TrackingAuthorizationState
        let hasAcceptedDisclosure: Bool
    }

    let exportedAt: Date
    let app: AppMetadata
    let profile: ProfileData
    let progress: ProgressData
    let adPreferences: AdPreferencesData
}

@MainActor
private enum LocalDataExportBuilder {
    static func build() -> LocalDataExport {
        build(
            profileStore: StudentProfileStore.shared,
            contentStore: ContentStore.shared,
            adPreferences: AdPreferencesStore.shared
        )
    }

    static func build(
        profileStore: StudentProfileStore,
        contentStore: ContentStore,
        adPreferences: AdPreferencesStore
    ) -> LocalDataExport {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"

        let categories = contentStore.categories
        let totalTasks = categories.flatMap(\.tasks).count
        let completedTasks = categories.flatMap(\.tasks).filter(\.isComplete).count
        let progressComponents = ContentStore.progressSnapshotComponents(from: categories)

        var customTasksByCategory: [String: [LocalDataExport.ProgressData.CustomTask]] = [:]
        for (categoryID, tasks) in progressComponents.customTasksByCategory {
            let mapped = tasks.map { task in
                LocalDataExport.ProgressData.CustomTask(
                    id: task.id,
                    title: task.title,
                    detail: task.detail,
                    isComplete: task.isComplete,
                    urgency: task.urgency,
                    timing: task.timing,
                    priority: task.priority
                )
            }
            if !mapped.isEmpty {
                customTasksByCategory[categoryID] = mapped
            }
        }

        return LocalDataExport(
            exportedAt: Date(),
            app: LocalDataExport.AppMetadata(
                version: version,
                build: build,
                environment: AppConfig.environment.rawValue
            ),
            profile: LocalDataExport.ProfileData(
                authProvider: profileStore.authProvider,
                fullName: profileStore.fullName,
                email: profileStore.email,
                selectedUniversity: profileStore.selectedUniversity,
                courseName: profileStore.courseName,
                city: profileStore.city,
                studyLevel: profileStore.studyLevel,
                arrivalDate: profileStore.arrivalDate,
                hasCompletedSetup: profileStore.hasCompletedSetup
            ),
            progress: LocalDataExport.ProgressData(
                totalTasks: totalTasks,
                completedTasks: completedTasks,
                completedTaskIDs: progressComponents.completedTaskIDs,
                customTasksByCategory: customTasksByCategory
            ),
            adPreferences: LocalDataExport.AdPreferencesData(
                wantsPersonalizedAds: adPreferences.wantsPersonalizedAds,
                trackingAuthorizationState: adPreferences.trackingAuthorizationState,
                hasAcceptedDisclosure: adPreferences.hasAcceptedDisclosure
            )
        )
    }

    nonisolated static func writeExportFile(data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let fileName = "ArrivalUK-Export-\(stamp).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
