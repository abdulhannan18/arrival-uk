import SwiftUI
import AuthenticationServices
import NaturalLanguage

struct SmartAddAnalysis {
    let detectedCategoryID: String?
    let detectedDate: Date?
    let cleanedTitle: String
}

struct SmartAddCommitResult {
    let categories: [ChecklistCategory]
    let categoryTitle: String
    let taskTitle: String
}

enum SmartAddInputEngine {
    static let keywordMap: [String: [String]] = [
        "before_arrival": ["flight", "passport", "packing", "visa", "brp", "ticket", "arrival", "immigration"],
        "academic_setup": ["lecture", "timetable", "module", "seminar", "library", "course", "exam", "assignment"],
        "health_admin": ["gp", "doctor", "dentist", "nhs", "hospital", "gym", "medical", "vaccination", "prescription"],
        "money_banking": ["bank", "account", "money", "card", "salary", "budget", "rent", "bill", "payslip"],
        "housing": ["housing", "accommodation", "rent", "tenancy", "landlord", "flat", "deposit", "lease"],
        "work_career": ["job", "work", "internship", "cv", "resume", "interview", "career"],
        "travel_transport": ["train", "bus", "tube", "tram", "travel", "oyster", "railcard", "taxi"],
        "legal_docs": ["legal", "document", "police", "council", "tax", "visa", "brp", "passport"],
        "shopping_essentials": ["shopping", "groceries", "supermarket", "food", "ikea", "kitchen", "bedding"],
        "communication_setup": ["sim", "phone", "number", "call", "sms", "whatsapp"],
        "insurance_safety": ["insurance", "safety", "emergency", "police", "ambulance"],
        "student_discounts": ["discount", "unidays", "totum", "student", "deal"],
        "internet_tech": ["wifi", "internet", "broadband", "laptop", "router", "tech"],
        "social_networking": ["club", "society", "friends", "meetup", "networking", "social"],
        "student_life": ["laundry", "cook", "kitchen", "routine", "life", "campus"]
    ]

    static func analyze(_ input: String) -> SmartAddAnalysis {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SmartAddAnalysis(
                detectedCategoryID: nil,
                detectedDate: nil,
                cleanedTitle: ""
            )
        }

        let lowered = trimmed.lowercased()
        let tokens = tokenize(lowered)
        let detectedCategoryID = detectCategoryID(tokens: tokens)
        let dateMatch = detectDate(in: trimmed)
        let cleanedTitle = extractedTitle(from: trimmed, removing: dateMatch?.range)

        return SmartAddAnalysis(
            detectedCategoryID: detectedCategoryID,
            detectedDate: dateMatch?.date,
            cleanedTitle: cleanedTitle
        )
    }

    static func tokenize(_ text: String) -> Set<String> {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var output: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            output.append(String(text[range]))
            return true
        }
        return Set(output)
    }

    static func detectCategoryID(tokens: Set<String>) -> String? {
        var bestID: String?
        var bestScore = 0

        for (categoryID, keywords) in keywordMap {
            let score = keywords.reduce(0) { partial, keyword in
                partial + (tokens.contains(keyword) ? 1 : 0)
            }
            if score > bestScore {
                bestScore = score
                bestID = categoryID
            }
        }

        return bestScore > 0 ? bestID : nil
    }

    static func detectDate(in text: String) -> (date: Date, range: Range<String.Index>)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.matches(in: text, range: nsRange).first, let date = match.date else {
            return nil
        }

        guard let range = Range(match.range, in: text) else {
            return nil
        }

        return (date: date, range: range)
    }

    static func extractedTitle(from raw: String, removing range: Range<String.Index>? = nil) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateRange = range ?? detectDate(in: raw)?.range
        guard let dateRange else { return trimmed }

        var modified = raw
        modified.removeSubrange(dateRange)

        let cleaned = modified
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",.-"))

        return cleaned.isEmpty ? trimmed : cleaned
    }

    static func urgency(for dueDate: Date?) -> TaskUrgency {
        guard let dueDate else { return .medium }
        let delta = dueDate.timeIntervalSinceNow
        if delta <= (3 * 24 * 60 * 60) {
            return .high
        }
        if delta <= (10 * 24 * 60 * 60) {
            return .medium
        }
        return .low
    }

    static func commitTask(
        rawInput: String,
        categories: [ChecklistCategory],
        fallbackCategoryID: String,
        detectedCategoryID: String?,
        detectedDate: Date?
    ) -> SmartAddCommitResult? {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }
        guard !categories.isEmpty else { return nil }

        let analysis = analyze(trimmedInput)
        let resolvedCategoryID = detectedCategoryID ?? analysis.detectedCategoryID ?? fallbackCategoryID
        let targetCategoryIndex = categories.firstIndex(where: { $0.id == resolvedCategoryID })
            ?? categories.firstIndex(where: { $0.id == fallbackCategoryID })
            ?? 0

        let dueDate = detectedDate ?? analysis.detectedDate
        let title = analysis.cleanedTitle
        let newTask = ChecklistTask(
            title: title,
            detail: nil,
            isComplete: false,
            isCustom: true,
            estimatedMinutes: nil,
            dueDate: dueDate,
            urgency: urgency(for: dueDate),
            order: nil,
            timing: .anytime,
            priority: .shouldDo,
            content: nil,
            sourceTitle: nil,
            sourceURL: nil
        )

        var updatedCategories = categories
        updatedCategories[targetCategoryIndex].tasks.append(newTask)
        let categoryTitle = updatedCategories[targetCategoryIndex].title

        return SmartAddCommitResult(
            categories: updatedCategories,
            categoryTitle: categoryTitle,
            taskTitle: title
        )
    }
}

struct SmartAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var categories: [ChecklistCategory]
    let fallbackCategoryID: String
    let onTaskAdded: (_ categoryTitle: String, _ taskTitle: String) -> Void
    var onClose: (() -> Void)? = nil

    @State private var inputText: String = ""
    @State private var detectedCategoryID: String?
    @State private var detectedDate: Date?
    @State private var lastHapticCategoryID: String?
    @FocusState private var isInputFocused: Bool

    private var normalizedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedCategoryID: String {
        detectedCategoryID ?? fallbackCategoryID
    }

    private var resolvedCategoryTitle: String {
        categories.first(where: { $0.id == resolvedCategoryID })?.title
            ?? categories.first(where: { $0.id == fallbackCategoryID })?.title
            ?? HomeLocalization.sectionBeforeArrivalTitle
    }

    private var resolvedDueDateLabel: String? {
        guard let date = detectedDate else { return nil }
        return UKLocaleFormat.mediumDateString(date)
    }

    private var canSend: Bool {
        !normalizedInput.isEmpty
    }

    private var predictionText: String? {
        guard canSend else { return nil }
        return HomeLocalization.quickAddPrediction(resolvedCategoryTitle)
    }

    private var dueContextText: String? {
        guard let dueLabel = resolvedDueDateLabel else { return nil }
        return HomeLocalization.quickAddDueContext(dueLabel)
    }

    private var predictionTint: Color {
        categories.first(where: { $0.id == resolvedCategoryID }).map {
            Theme.categoryText(for: $0, among: categories)
        } ?? Theme.secondaryText
    }

    private var magicSymbolName: String {
        switch resolvedCategoryID {
        case "health_admin":
            return "heart.fill"
        case "travel_transport":
            return "tram.fill"
        case "money_banking":
            return "creditcard.fill"
        case "housing":
            return "house.fill"
        case "academic_setup":
            return "graduationcap.fill"
        case "legal_docs":
            return "doc.text.fill"
        case "shopping_essentials":
            return "bag.fill"
        case "communication_setup":
            return "iphone"
        case "internet_tech":
            return "wifi"
        case "work_career":
            return "briefcase.fill"
        case "student_discounts":
            return "tag.fill"
        case "social_networking":
            return "person.3.fill"
        case "insurance_safety":
            return "shield.fill"
        case "student_life":
            return "backpack.fill"
        default:
            return "sparkles"
        }
    }

    private var magicGradient: LinearGradient {
        let palette = categories.first(where: { $0.id == resolvedCategoryID }).map { Theme.palette(for: $0, among: categories) }
        if let palette {
            return palette.linearGradient
        }
        return LinearGradient(
            colors: [Theme.brandPrimary, Theme.brandSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            HStack {
                Text("Quick Add")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Theme.track)
                        )
                }
                .buttonStyle(AppFastButtonStyle())
                .accessibilityLabel("Close")
            }

            VStack(spacing: Theme.spaceS) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(magicGradient)
                            .frame(width: 38, height: 38)

                        Image(systemName: magicSymbolName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: magicSymbolName)
                    .accessibilityHidden(true)

                    TextField("What do you need to do?", text: $inputText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            saveTaskIfPossible()
                        }

                    Button(action: saveTaskIfPossible) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(canSend ? Theme.cosmicBlue : Theme.tertiaryText.opacity(0.55))
                    }
                    .buttonStyle(AppFastButtonStyle())
                    .disabled(!canSend)
                    .accessibilityLabel("Add task")
                    .accessibilityHint("Saves the new task")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .stroke(Theme.stroke.opacity(0.55), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    SmartAddChip(
                        icon: "square.grid.2x2.fill",
                        label: resolvedCategoryTitle,
                        tint: Theme.primaryText
                    )
                    .accessibilityLabel("Category \(resolvedCategoryTitle)")

                    if let dueLabel = resolvedDueDateLabel {
                        SmartAddChip(
                            icon: "calendar",
                            label: dueLabel,
                            tint: Theme.brandPrimary
                        )
                        .accessibilityLabel("Due \(dueLabel)")
                    }

                    Spacer(minLength: 0)
                }

                if let predictionText {
                    HStack(spacing: 6) {
                        Image(systemName: magicSymbolName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(predictionText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        if let dueContextText {
                            Text("•")
                                .foregroundStyle(Theme.tertiaryText)
                            Text(dueContextText)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(predictionTint)
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.horizontal, Theme.spaceXL)
        .padding(.bottom, Theme.spaceM)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: AppTiming.smartAddFocusDelay)
                isInputFocused = true
            }
        }
        .onChange(of: inputText) { _, newValue in
            analyzeInput(newValue)
        }
    }

    private func analyzeInput(_ text: String) {
        let analysis = SmartAddInputEngine.analyze(text)
        let nextCategoryID = analysis.detectedCategoryID
        if nextCategoryID != detectedCategoryID {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                detectedCategoryID = nextCategoryID
            }

            if nextCategoryID != nil, nextCategoryID != lastHapticCategoryID {
                lastHapticCategoryID = nextCategoryID
                Haptics.selectionIfAllowed()
            }
        }

        detectedDate = analysis.detectedDate
    }

    private func saveTaskIfPossible() {
        let rawInput = normalizedInput
        guard !rawInput.isEmpty else { return }
        guard !categories.isEmpty else {
            close()
            return
        }

        guard let commit = SmartAddInputEngine.commitTask(
            rawInput: rawInput,
            categories: categories,
            fallbackCategoryID: fallbackCategoryID,
            detectedCategoryID: detectedCategoryID,
            detectedDate: detectedDate
        ) else {
            return
        }

        Motion.mutate {
            categories = commit.categories
        }

        onTaskAdded(commit.categoryTitle, commit.taskTitle)
        Haptics.successIfAllowed()
        close()
    }

    private func close() {
        onClose?()
        dismiss()
    }
}

private struct SmartAddChip: View {
    let icon: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct ProfileSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let store: StudentProfileStore
    let contentStore: ContentStore
    var onOpenHelp: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    @State private var fullName: String
    @State private var googleEmailInput: String
    @State private var selectedUniversity: String
    @State private var customUniversity: String
    @State private var courseName: String
    @State private var city: String
    @State private var studyLevel: StudyLevel
    @State private var arrivalDate: Date
    @State private var showGoogleInfo = false
    @State private var showGoogleSignInError = false
    @State private var googleSignInErrorMessage = ""
    @State private var isGoogleSignInInFlight = false
    @State private var showSwitchProviderAlert = false
    @State private var showSignOutAlert = false
    @State private var pendingProviderSwitch: StudentAuthProvider = .none
    @State private var acceptedConsents: Set<RegionalConsentRequirement>

    init(
        store: StudentProfileStore,
        contentStore: ContentStore,
        onOpenHelp: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.store = store
        self.contentStore = contentStore
        self.onOpenHelp = onOpenHelp
        self.onClose = onClose
        self._fullName = State(initialValue: store.fullName)
        self._googleEmailInput = State(initialValue: store.email)
        self._courseName = State(initialValue: store.courseName)
        self._city = State(initialValue: store.city)
        self._studyLevel = State(initialValue: store.studyLevel)
        self._arrivalDate = State(initialValue: store.arrivalDate)
        self._acceptedConsents = State(initialValue: Set(RegionRuntime.consentRequirements))

        if UniversityCatalog.popularUK.contains(store.selectedUniversity) {
            self._selectedUniversity = State(initialValue: store.selectedUniversity)
            self._customUniversity = State(initialValue: "")
        } else if !store.selectedUniversity.isEmpty {
            self._selectedUniversity = State(initialValue: "Other")
            self._customUniversity = State(initialValue: store.selectedUniversity)
        } else {
            self._selectedUniversity = State(initialValue: UniversityCatalog.popularUK.first ?? "Other")
            self._customUniversity = State(initialValue: "")
        }
    }

    private var resolvedUniversity: String {
        if selectedUniversity == "Other" {
            return customUniversity.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedUniversity
    }

    private var normalizedName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedGoogleEmail: String {
        googleEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var requiresGoogleEmail: Bool {
        store.authProvider == .google
    }

    private var isGoogleEmailValid: Bool {
        AuthStateValidator.isValidEmail(normalizedGoogleEmail)
    }

    private var canSave: Bool {
        guard !normalizedName.isEmpty && !resolvedUniversity.isEmpty else { return false }
        let hasAllRequiredConsents = Set(requiredConsents).isSubset(of: acceptedConsents)
        guard hasAllRequiredConsents else { return false }
        if requiresGoogleEmail {
            return isGoogleEmailValid
        }
        return true
    }

    private var requiredConsents: [RegionalConsentRequirement] {
        RegionRuntime.consentRequirements
    }

    private var regionComplianceLine: String {
        let profile = RegionRuntime.complianceProfile.rawValue.replacingOccurrences(of: "_", with: " ").uppercased()
        return "\(RegionRuntime.activeConfiguration.displayName) • \(profile)"
    }

    private var googleStatusLabel: String {
        guard store.authProvider == .google else { return "Email mode" }
        return store.googleUserID == nil ? "Email mode" : "Connected"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Login") {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleAppleSignIn
                    )
                    .signInWithAppleButtonStyle(
                        colorScheme == .dark ? .white : .black
                    )
                    .frame(height: 44)

                    if store.authProvider == .apple {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await handleGoogleTap() }
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                            Text(isGoogleSignInInFlight ? "Connecting Google..." : "Continue with Google")
                            Spacer()
                            Text(googleStatusLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(AppFastButtonStyle())
                    .disabled(isGoogleSignInInFlight)

                    if store.authProvider == .google || !googleEmailInput.isEmpty {
                        TextField("Google email", text: $googleEmailInput)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        if !normalizedGoogleEmail.isEmpty && !isGoogleEmailValid {
                            Text("Enter a valid email address")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    if store.authProvider != .none {
                        Button("Sign out", role: .destructive) {
                            showSignOutAlert = true
                        }
                    }

                    Text("Current login: \(store.authProvider.label)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Student Details") {
                    TextField("Full name", text: $fullName)

                    Picker("University", selection: $selectedUniversity) {
                        ForEach(UniversityCatalog.popularUK, id: \.self) { university in
                            Text(university).tag(university)
                        }
                        Text("Other").tag("Other")
                    }

                    if selectedUniversity == "Other" {
                        TextField("Enter university name", text: $customUniversity)
                    }

                    TextField("Course", text: $courseName)
                    TextField("City", text: $city)

                    Picker("Study level", selection: $studyLevel) {
                        ForEach(StudyLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }

                    DatePicker("Arrival date", selection: $arrivalDate, displayedComponents: .date)
                }

                if !requiredConsents.isEmpty {
                    Section("Legal Consent") {
                        Text(regionComplianceLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ForEach(requiredConsents, id: \.rawValue) { consent in
                            Toggle(
                                isOn: Binding(
                                    get: { acceptedConsents.contains(consent) },
                                    set: { isAccepted in
                                        if isAccepted {
                                            acceptedConsents.insert(consent)
                                        } else {
                                            acceptedConsents.remove(consent)
                                        }
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(consentTitle(consent))
                                        .font(.subheadline.weight(.semibold))
                                    Text(consentSubtitle(consent))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Support") {
                    Button {
                        if let onOpenHelp {
                            onOpenHelp()
                        } else {
                            close()
                        }
                    } label: {
                        Label("Help & Privacy", systemImage: "questionmark.circle")
                    }
                    .buttonStyle(AppFastButtonStyle())
                }
            }
            .navigationTitle("Student Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { close() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                        .disabled(!canSave)
                }
            }
            .alert("Google Sign-In Setup", isPresented: $showGoogleInfo) {
                Button("Use Email Mode") {
                    store.setGoogleMode()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Google Sign-In SDK is not linked or configured. Add GoogleService-Info.plist and GoogleSignIn package, then this button will open Google account login.")
            }
            .alert("Google Sign-In Failed", isPresented: $showGoogleSignInError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(googleSignInErrorMessage)
            }
            .alert("Switch Login Provider?", isPresented: $showSwitchProviderAlert) {
                Button("Switch") {
                    if pendingProviderSwitch == .google {
                        Task { await beginGoogleSignIn() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Switching providers signs out the current account for this device. Your profile data stays saved.")
            }
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    GoogleSignInBridge.signOut()
                    store.secureSignOut(contentStore: .shared)
                    NotificationManager.shared.cancelAllReminders()
                    googleEmailInput = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign in again anytime.")
            }
        }
    }

    private func handleGoogleTap() async {
        if store.authProvider == .apple {
            pendingProviderSwitch = .google
            showSwitchProviderAlert = true
            return
        }
        await beginGoogleSignIn()
    }

    @MainActor
    private func beginGoogleSignIn() async {
        if !GoogleSignInBridge.isSDKLinked {
            showGoogleInfo = true
            return
        }

        isGoogleSignInInFlight = true
        defer { isGoogleSignInInFlight = false }

        do {
            let identity = try await GoogleSignInBridge.signIn(
                presenting: PresentationAnchor.topViewController()
            )
            store.applyGoogleIdentity(identity)
            googleEmailInput = identity.email

            if normalizedName.isEmpty, let fullName = identity.fullName, !fullName.isEmpty {
                self.fullName = fullName
            }
        } catch GoogleSignInBridgeError.cancelled {
            return
        } catch let knownError as GoogleSignInBridgeError {
            CrashReporter.record(
                error: knownError,
                context: "google_sign_in",
                metadata: ["error": String(describing: knownError)]
            )
            googleSignInErrorMessage = knownError.errorDescription ?? "Google Sign-In failed."
            showGoogleSignInError = true
        } catch {
            CrashReporter.record(
                error: error,
                context: "google_sign_in",
                metadata: ["phase": "unexpected"]
            )
            googleSignInErrorMessage = "Google Sign-In failed. Please try again."
            showGoogleSignInError = true
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            store.applyAppleCredential(credential)

            if normalizedName.isEmpty, !store.fullName.isEmpty {
                fullName = store.fullName
            }
        case .failure(let error):
            CrashReporter.record(
                error: error,
                context: "apple_sign_in",
                metadata: ["provider": "apple"]
            )
            break
        }
    }

    private func saveProfile() {
        if store.authProvider == .google {
            store.setGoogleIdentity(email: normalizedGoogleEmail)
        }

        store.updateProfile(
            fullName: normalizedName,
            selectedUniversity: resolvedUniversity,
            courseName: courseName,
            city: city,
            studyLevel: studyLevel,
            arrivalDate: arrivalDate
        )

        Task {
            let allowed = await NotificationManager.shared.requestPermissionIfNeeded(
                promptIfUndetermined: true
            )
            guard allowed else { return }
            await NotificationManager.shared.refreshTaskReminders(
                categories: contentStore.categories
            )
        }

        close()
    }

    private func close() {
        onClose?()
        dismiss()
    }

    private func consentTitle(_ requirement: RegionalConsentRequirement) -> String {
        switch requirement {
        case .termsOfService:
            return "Accept Terms of Service"
        case .privacyPolicy:
            return "Accept Privacy Policy"
        case .dataProcessing:
            return "Allow Data Processing"
        case .doNotSell:
            return "Do Not Sell Preference"
        case .dataResidencyNotice:
            return "Acknowledge Data Residency"
        case .financialDisclosure:
            return "Accept Financial Disclosure"
        }
    }

    private func consentSubtitle(_ requirement: RegionalConsentRequirement) -> String {
        switch requirement {
        case .termsOfService:
            return "Required to create and maintain your relocation workspace."
        case .privacyPolicy:
            return "Required for secure handling of profile and wallet data."
        case .dataProcessing:
            return "Required for lawful processing under your active region."
        case .doNotSell:
            return "Controls CCPA/CPRA data-sharing preferences."
        case .dataResidencyNotice:
            return "Confirms you reviewed regional data-hosting requirements."
        case .financialDisclosure:
            return "Required before using banking and marketplace flows."
        }
    }
}

#Preview {
    ContentView()
}
