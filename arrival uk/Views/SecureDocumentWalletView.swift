import PhotosUI
import SwiftUI
import UIKit

struct SecureDocumentWalletSection: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var isExpanded = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isAnalyzingDocument = false
    @State private var walletMessage: String?
    @State private var isWalletMessageError = false
    @State private var sharePlayCoordinator = DocumentReviewSharePlayCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Text("SECURE DOCUMENT WALLET")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: AppTheme.Spacing.sm)

                if walletManager.isUnlocked {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Scan", systemImage: "doc.viewfinder")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(AppFastButtonStyle())
                    .foregroundStyle(AppTheme.Colors.actionPrimary)
                    .disabled(isAnalyzingDocument || walletManager.isPrivacyShieldActive)

                    Button("Lock") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isExpanded = false
                        }
                        walletManager.lock()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .buttonStyle(AppFastButtonStyle())
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            if walletManager.isUnlocked {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    if isAnalyzingDocument {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Analyzing document on-device...")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    } else if let walletMessage {
                        Text(walletMessage)
                            .font(.caption)
                            .foregroundStyle(isWalletMessageError ? AppTheme.Colors.statusUrgent : AppTheme.Colors.textSecondary)
                    } else {
                        Text("All document analysis runs locally on your device.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                ZStack {
                    DocumentFanView(
                        isExpanded: $isExpanded,
                        docs: walletManager.documents,
                        onOverrideType: { document, type in
                            walletManager.overrideDocumentType(for: document.id, with: type)
                            walletMessage = "\(document.type.title) changed to \(type.title)."
                            isWalletMessageError = false
                        },
                        onOpenInWindow: { document in
                            ArrivalWindowSceneBridge.requestPinnedDocumentWindow(for: document.id)
                            walletMessage = "\(document.type.title) opened in a separate window."
                            isWalletMessageError = false
                        },
                        onStartSharePlay: { document, redactedMode in
                            Task {
                                let didStart = await sharePlayCoordinator.startReview(
                                    for: document,
                                    redactedMode: redactedMode
                                )
                                await MainActor.run {
                                    if didStart {
                                        walletMessage = redactedMode
                                            ? "\(document.type.title) SharePlay started (redacted mode)."
                                            : "\(document.type.title) SharePlay started (full access, 5 min token)."
                                        isWalletMessageError = false
                                    } else {
                                        walletMessage = "SharePlay unavailable right now."
                                        isWalletMessageError = true
                                    }
                                }
                            }
                        }
                    )
                    .blur(radius: walletManager.isPrivacyShieldActive ? AppTheme.Layout.walletPrivacyBlurRadius : 0)
                    .allowsHitTesting(!walletManager.isPrivacyShieldActive)

                    if walletManager.isPrivacyShieldActive {
                        WalletPrivacyShieldView()
                            .transition(.opacity)
                    }
                }
            } else {
                LockedWalletPrompt {
                    walletManager.requestAccess()
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.xl)
        .onChange(of: selectedPhotoItem) { _, nextItem in
            guard let nextItem else { return }
            analyzeSelectedDocument(nextItem)
        }
        .onDisappear {
            isExpanded = false
            selectedPhotoItem = nil
        }
    }

    private func analyzeSelectedDocument(_ photoItem: PhotosPickerItem) {
        Task {
            await MainActor.run {
                isAnalyzingDocument = true
                walletMessage = nil
                isWalletMessageError = false
            }

            var message = "Document was classified and added to your wallet."
            var didFail = false

            do {
                guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: imageData) else {
                    message = "Selected file could not be read."
                    didFail = true
                    await MainActor.run {
                        isAnalyzingDocument = false
                        selectedPhotoItem = nil
                        walletMessage = message
                        isWalletMessageError = didFail
                    }
                    return
                }

                let didStore = await walletManager.analyzeAndStoreDocument(image)
                if !didStore {
                    message = "Could not classify this document. Use manual category override."
                    didFail = true
                }
            } catch {
                message = "Document scan failed. Please try another image."
                didFail = true
            }

            await MainActor.run {
                isAnalyzingDocument = false
                selectedPhotoItem = nil
                walletMessage = message
                isWalletMessageError = didFail
            }
        }
    }
}

struct DocumentFanView: View {
    @Binding var isExpanded: Bool
    let docs: [SecureDoc]
    let onOverrideType: (SecureDoc, SecureDocType) -> Void
    let onOpenInWindow: (SecureDoc) -> Void
    let onStartSharePlay: (SecureDoc, Bool) -> Void

    private var centerIndex: Int {
        docs.count / 2
    }

    var body: some View {
        ZStack {
            ForEach(Array(docs.enumerated()), id: \.element.id) { index, doc in
                DocumentCard(
                    doc: doc,
                    onOverrideType: { type in
                        onOverrideType(doc, type)
                    },
                    onOpenInWindow: {
                        onOpenInWindow(doc)
                    },
                    onStartSharePlay: { redactedMode in
                        onStartSharePlay(doc, redactedMode)
                    }
                )
                .rotationEffect(
                    .degrees(
                        isExpanded
                            ? Double(index - centerIndex) * AppTheme.Layout.walletFanRotationDelta
                            : .zero
                    ),
                    anchor: .bottom
                )
                .offset(
                    x: isExpanded
                        ? CGFloat(index - centerIndex) * AppTheme.Layout.walletFanOffset
                        : .zero
                )
                .zIndex(Double(docs.count - index))
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: isExpanded
                ? AppTheme.Layout.walletExpandedStackHeight
                : AppTheme.Layout.walletCollapsedStackHeight
        )
    }
}

private struct DocumentCard: View {
    let doc: SecureDoc
    let onOverrideType: (SecureDocType) -> Void
    let onOpenInWindow: () -> Void
    let onStartSharePlay: (Bool) -> Void

    private var statusColor: Color {
        switch doc.status {
        case .verified:
            return Theme.successMain
        case .pending:
            return AppTheme.Colors.actionPrimary
        case .expiringSoon:
            return AppTheme.Colors.statusUrgent
        }
    }

    private var formattedDate: String {
        UKLocaleFormat.mediumDateString(doc.lastUpdatedAt)
    }

    private var classificationPill: String? {
        switch doc.classificationSource {
        case .manual:
            return "Manual"
        case .visionOCR:
            if let confidence = doc.classificationConfidence {
                return "Auto \(Int((confidence * 100).rounded()))%"
            }
            return "Auto"
        case .remoteTemplate:
            return "Template"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: doc.type.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.actionPrimary)

                Text(doc.type.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(doc.status.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(statusColor.opacity(0.12), in: Capsule())

                Menu {
                    Section("Correct Category") {
                        ForEach(SecureDocType.allCases, id: \.self) { type in
                            Button {
                                onOverrideType(type)
                            } label: {
                                Label(
                                    type.title,
                                    systemImage: type == doc.type ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                    }

                    Section("Window") {
                        Button {
                            onOpenInWindow()
                        } label: {
                            Label("Open in New Window", systemImage: "macwindow.on.rectangle")
                        }
                    }

                    Section("Collaboration") {
                        Button {
                            onStartSharePlay(true)
                        } label: {
                            Label("SharePlay (Redacted)", systemImage: "shareplay")
                        }
                        Button {
                            onStartSharePlay(false)
                        } label: {
                            Label("SharePlay (Full 5m Token)", systemImage: "person.2.badge.key")
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(
                            width: AppTheme.Layout.minimumTouchTarget,
                            height: AppTheme.Layout.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: .zero)

            Text(doc.holderName)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(doc.reference)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(spacing: AppTheme.Spacing.sm) {
                Text("Updated \(formattedDate)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                if let classificationPill {
                    Text(classificationPill)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.actionPrimary)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.actionPrimary.opacity(0.10), in: Capsule())
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Colors.bgSurface,
                    AppTheme.Colors.actionPrimary.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.walletCardCornerRadius,
                style: .continuous
            )
            .stroke(AppTheme.Colors.textSecondary.opacity(0.10), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.walletCardCornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(0.16),
            radius: AppTheme.Layout.walletCardShadowRadius,
            x: 0,
            y: AppTheme.Layout.walletCardShadowYOffset
        )
        .contextMenu {
            Button {
                onOpenInWindow()
            } label: {
                Label("Open in New Window", systemImage: "macwindow.on.rectangle")
            }
            Button {
                onStartSharePlay(true)
            } label: {
                Label("SharePlay (Redacted)", systemImage: "shareplay")
            }
            Button {
                onStartSharePlay(false)
            } label: {
                Label("SharePlay (Full 5m Token)", systemImage: "person.2.badge.key")
            }
        }
        .frame(maxWidth: AppTheme.Layout.walletCardMaxWidth)
        .aspectRatio(AppTheme.Layout.walletCardAspectRatio, contentMode: .fit)
        .hoverEffect(.lift)
        .accessibilityElement(children: .combine)
    }
}

private struct LockedWalletPrompt: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Documents are locked")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Use Face ID or passcode to access your UK entry documents.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Button(action: onUnlock) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "faceid")
                    Text("Unlock Wallet")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.actionPrimary, in: Capsule())
            }
            .buttonStyle(AppFastButtonStyle())
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.bgSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.walletCardCornerRadius,
                style: .continuous
            )
        )
    }
}

struct WalletPrivacyShieldView: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.Layout.walletCardCornerRadius,
            style: .continuous
        )
        .fill(AppTheme.Colors.bgPrimary.opacity(0.94))
        .overlay {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("Hidden in App Switcher")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Spacing.md)
        }
        .frame(maxWidth: AppTheme.Layout.walletCardMaxWidth)
        .aspectRatio(AppTheme.Layout.walletCardAspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
