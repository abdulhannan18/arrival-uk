import SwiftUI

struct PinnedDocumentWindowView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var walletManager = WalletManager()
    @State private var pinnedDocumentID: UUID?

    private var pinnedDocument: SecureDoc? {
        if let pinnedDocumentID {
            return walletManager.documents.first(where: { $0.id == pinnedDocumentID })
        }
        return walletManager.documents.first
    }

    private var needsPrivacyShield: Bool {
        scenePhase != .active || walletManager.isPrivacyShieldActive
    }

    var body: some View {
        ZStack {
            Theme.background(for: .dark, conservative: true)
                .ignoresSafeArea()

            content
                .padding(AppTheme.Spacing.lg)
                .blur(radius: needsPrivacyShield ? 22 : 0)
                .animation(.easeInOut(duration: 0.22), value: needsPrivacyShield)

            if needsPrivacyShield {
                WalletPrivacyShieldView()
                    .padding(AppTheme.Spacing.lg)
            }
        }
        .onContinueUserActivity(ArrivalContinuity.openDocumentActivityType) { activity in
            applyDocumentID(from: activity)
        }
        .onChange(of: scenePhase) { _, newValue in
            walletManager.handleScenePhaseChange(newValue)
        }
        .task {
            walletManager.bootstrapIfNeeded()
            walletManager.handleScenePhaseChange(scenePhase)
            if let stagedDocumentID = ArrivalWindowSceneBridge.stagedPinnedDocumentID() {
                applyDocumentID(stagedDocumentID)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if walletManager.isUnlocked {
            if let pinnedDocument {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Label("Pinned Document", systemImage: "pin.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: pinnedDocument.type.symbolName)
                                .font(.title3.weight(.semibold))
                            Text(pinnedDocument.type.title)
                                .font(.title3.weight(.bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.primary)

                        Text(pinnedDocument.holderName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(pinnedDocument.reference)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Updated \(UKLocaleFormat.mediumDateString(pinnedDocument.lastUpdatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.Colors.textSecondary.opacity(0.18), lineWidth: 1)
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("No document selected")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Long-press a wallet card and choose Open in New Window.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Pinned document is locked")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Unlock to reveal this document in the separate window.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Unlock") {
                    walletManager.requestAccess()
                }
                .buttonStyle(AppFastButtonStyle())
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
    }

    @MainActor
    private func applyDocumentID(from activity: NSUserActivity) {
        guard let documentID = ArrivalWindowSceneBridge.documentID(from: activity) else { return }
        applyDocumentID(documentID)
    }

    @MainActor
    private func applyDocumentID(_ documentID: UUID) {
        pinnedDocumentID = documentID
        ArrivalWindowSceneBridge.stagePinnedDocumentID(documentID)
        walletManager.focusDocument(id: documentID)
    }
}
