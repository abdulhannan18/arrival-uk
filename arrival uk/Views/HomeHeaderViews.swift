import SwiftUI

enum HomeLocalization {
    private static var languageCode: String {
        Locale.autoupdatingCurrent.language.languageCode?.identifier.lowercased() ?? "en"
    }

    static var isRightToLeft: Bool {
        if #available(iOS 16.0, *) {
            return Locale.Language(identifier: languageCode).characterDirection == .rightToLeft
        }
        return NSLocale.characterDirection(forLanguage: languageCode) == .rightToLeft
    }

    private static var isUrdu: Bool {
        languageCode == "ur"
    }

    private static var isArabic: Bool {
        languageCode == "ar"
    }

    private static var destinationName: String {
        RegionRuntime.activeConfiguration.displayName
    }

    private static var destinationCode: String {
        switch RegionRuntime.activeRegion {
        case .uk:
            return "UK"
        case .usa:
            return "USA"
        case .canada:
            return "Canada"
        case .australia:
            return "Australia"
        case .global:
            return "destination"
        }
    }

    private static func pick(en: String, ur: String, ar: String) -> String {
        if isUrdu { return ur }
        if isArabic { return ar }
        return en
    }

    static func localizedNumber(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .none)
    }

    static func greeting(for hour: Int) -> String {
        if hour < 12 {
            return pick(en: "Good morning", ur: "صبح بخیر", ar: "صباح الخير")
        }
        if hour < 18 {
            return pick(en: "Good afternoon", ur: "دوپہر بخیر", ar: "مساء الخير")
        }
        return pick(en: "Good evening", ur: "شام بخیر", ar: "مساء الخير")
    }

    static var journeyTagline: String {
        pick(
            en: "Your journey to \(destinationName) starts here",
            ur: "\(destinationCode) کا سفر یہاں سے شروع ہوتا ہے",
            ar: "رحلتك إلى \(destinationName) تبدأ هنا"
        )
    }

    static func adaptiveHeaderMessage(for completionPercent: Int) -> String {
        switch completionPercent {
        case 0:
            return pick(
                en: "Welcome. Let's get you settled.",
                ur: "خوش آمدید۔ آئیے آپ کو جلدی سیٹل کریں۔",
                ar: "مرحبًا. لنبدأ تنظيم استقرارك."
            )
        case 1..<15:
            return pick(
                en: "Good start. Keep going.",
                ur: "اچھی شروعات۔ اسی طرح جاری رکھیں۔",
                ar: "بداية جيدة. استمر."
            )
        case 15..<40:
            return pick(
                en: "You're making strong progress.",
                ur: "آپ مضبوط پیش رفت کر رہے ہیں۔",
                ar: "أنت تحقق تقدمًا قويًا."
            )
        case 40..<70:
            return pick(
                en: "You're ahead of most students at this stage.",
                ur: "اس مرحلے پر آپ زیادہ تر طلبہ سے آگے ہیں۔",
                ar: "أنت متقدم على معظم الطلاب في هذه المرحلة."
            )
        case 70..<90:
            return pick(
                en: "Almost there. The hard work is done.",
                ur: "تقریباً ہو گیا۔ مشکل حصہ مکمل ہوچکا ہے۔",
                ar: "اقتربت جدًا. الجزء الأصعب انتهى."
            )
        case 90..<100:
            return pick(
                en: "Nearly complete. Finish strong.",
                ur: "تقریباً مکمل۔ مضبوط اختتام کریں۔",
                ar: "قارب الاكتمال. أنهِ بقوة."
            )
        default:
            return pick(
                en: "You've got this completely handled.",
                ur: "آپ نے یہ کام مکمل طور پر سنبھال لیا ہے۔",
                ar: "لقد أتقنت هذا بالكامل."
            )
        }
    }

    static func streakLabel(days: Int) -> String {
        let value = localizedNumber(days)
        return pick(
            en: "Streak: \(value) day\(days == 1 ? "" : "s")",
            ur: "تسلسل: \(value) دن",
            ar: "سلسلة: \(value) يوم"
        )
    }

    static var arrivingToday: String {
        pick(en: "Arriving today", ur: "آج \(destinationCode) پہنچ رہے ہیں", ar: "الوصول اليوم")
    }

    static var arrivingTomorrow: String {
        pick(en: "Arriving tomorrow", ur: "کل \(destinationCode) پہنچ رہے ہیں", ar: "الوصول غدًا")
    }

    static func arrivingInDays(_ days: Int) -> String {
        let value = localizedNumber(days)
        return pick(
            en: "Arriving in \(value) days",
            ur: "\(value) دن میں \(destinationCode) پہنچ رہے ہیں",
            ar: "الوصول خلال \(value) يومًا"
        )
    }

    static func timelineUntilArrival(days: Int) -> String {
        let value = localizedNumber(days)
        return pick(
            en: "\(value) days until arrival",
            ur: "آمد میں \(value) دن باقی",
            ar: "\(value) يومًا حتى الوصول"
        )
    }

    static var timelineArrivalDay: String {
        pick(en: "Arrival day in \(destinationCode)", ur: "\(destinationCode) میں آمد کا دن", ar: "يوم الوصول في \(destinationName)")
    }

    static func timelineDayInUK(_ day: Int) -> String {
        let value = localizedNumber(day)
        return pick(
            en: "Day \(value) in \(destinationCode)",
            ur: "\(destinationCode) میں دن \(value)",
            ar: "اليوم \(value) في \(destinationName)"
        )
    }

    static var sectionBeforeArrivalTitle: String {
        pick(en: "Before Arrival", ur: "آمد سے پہلے", ar: "قبل الوصول")
    }

    static var sectionBeforeArrivalSubtitle: String {
        pick(
            en: "Must complete before landing",
            ur: "اترنے سے پہلے مکمل کریں",
            ar: "يجب إكمالها قبل الوصول"
        )
    }

    static var sectionWeekOneTitle: String {
        pick(en: "Week 1 Priorities", ur: "ہفتہ 1 ترجیحات", ar: "أولويات الأسبوع الأول")
    }

    static var sectionWeekOneSubtitle: String {
        pick(
            en: "Important first-week setup",
            ur: "پہلے ہفتے کی اہم ترتیب",
            ar: "إعدادات مهمة للأسبوع الأول"
        )
    }

    static var sectionMonthOneTitle: String {
        pick(en: "Weeks 2–4", ur: "ہفتے 2 تا 4", ar: "الأسابيع 2–4")
    }

    static var sectionMonthOneSubtitle: String {
        pick(
            en: "Plan these in your first month",
            ur: "پہلے مہینے میں ان کی منصوبہ بندی کریں",
            ar: "خطط لهذه المهام خلال الشهر الأول"
        )
    }

    static var sectionAnytimeTitle: String {
        pick(en: "Anytime Tasks", ur: "کبھی بھی کرنے والے کام", ar: "مهام في أي وقت")
    }

    static var sectionAnytimeSubtitle: String {
        pick(
            en: "Complete these when convenient",
            ur: "سہولت کے مطابق مکمل کریں",
            ar: "أكملها عندما يناسبك"
        )
    }

    static var sectionCompletedTitle: String {
        pick(en: "Completed", ur: "مکمل", ar: "مكتمل")
    }

    static var sectionCompletedSubtitle: String {
        pick(en: "Finished categories", ur: "مکمل شدہ کیٹیگریز", ar: "الفئات المكتملة")
    }

    static var filterAllTitle: String {
        pick(en: "All", ur: "سب", ar: "الكل")
    }

    static var filterBeforeArrivalTitle: String {
        pick(en: "Before Arrival", ur: "آمد سے پہلے", ar: "قبل الوصول")
    }

    static var filterWeekOneTitle: String {
        pick(en: "Week 1", ur: "ہفتہ 1", ar: "الأسبوع 1")
    }

    static var filterWeekTwoTitle: String {
        pick(en: "Week 2", ur: "ہفتہ 2", ar: "الأسبوع 2")
    }

    static var filterAnytimeTitle: String {
        pick(en: "Anytime", ur: "کبھی بھی", ar: "أي وقت")
    }

    static var filterCompletedTitle: String {
        pick(en: "Completed", ur: "مکمل", ar: "مكتمل")
    }

    static func filterSelectedA11y(_ label: String) -> String {
        pick(
            en: "\(label), selected",
            ur: "\(label)، منتخب",
            ar: "\(label)، محدد"
        )
    }

    static var expandCompletedSection: String {
        pick(en: "Expand completed section", ur: "مکمل سیکشن کھولیں", ar: "توسيع قسم المكتمل")
    }

    static var collapseCompletedSection: String {
        pick(en: "Collapse completed section", ur: "مکمل سیکشن بند کریں", ar: "طي قسم المكتمل")
    }

    static var completedSectionToggleHint: String {
        pick(
            en: "Toggles visibility of completed categories",
            ur: "مکمل کیٹیگریز کی نمائش تبدیل کریں",
            ar: "يبدل إظهار الفئات المكتملة"
        )
    }

    static var searchTasksLabel: String {
        pick(en: "Search tasks", ur: "ٹاسک تلاش کریں", ar: "ابحث في المهام")
    }

    static var addTaskLabel: String {
        pick(en: "Add task", ur: "ٹاسک شامل کریں", ar: "إضافة مهمة")
    }

    static var addTaskHint: String {
        pick(en: "Opens quick add", ur: "فوری اضافہ کھولتا ہے", ar: "يفتح الإضافة السريعة")
    }

    static var todayCardLabel: String {
        pick(en: "TODAY", ur: "آج", ar: "اليوم")
    }

    static func todayEstimatedMinutes(_ minutes: Int) -> String {
        let value = localizedNumber(minutes)
        return pick(
            en: "~\(value)m",
            ur: "~\(value) منٹ",
            ar: "~\(value) د"
        )
    }

    static var taskMarkedCompleteToast: String {
        pick(en: "Task marked complete", ur: "کام مکمل نشان زد ہوگیا", ar: "تم وضع علامة الإكمال على المهمة")
    }

    static func quickAddPrediction(_ categoryTitle: String) -> String {
        pick(
            en: "Will add to: \(categoryTitle)",
            ur: "یہاں شامل ہوگا: \(categoryTitle)",
            ar: "ستُضاف إلى: \(categoryTitle)"
        )
    }

    static func quickAddDueContext(_ dueLabel: String) -> String {
        pick(
            en: "Due: \(dueLabel)",
            ur: "آخری تاریخ: \(dueLabel)",
            ar: "الموعد: \(dueLabel)"
        )
    }

    static func quickAddSavedToast(taskTitle: String, categoryTitle: String) -> String {
        let task = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if task.isEmpty {
            return pick(
                en: "Task added to \(categoryTitle)",
                ur: "کام \(categoryTitle) میں شامل ہوگیا",
                ar: "تمت إضافة المهمة إلى \(categoryTitle)"
            )
        }

        return pick(
            en: "Added \"\(task)\" to \(categoryTitle)",
            ur: "\"\(task)\" کو \(categoryTitle) میں شامل کردیا گیا",
            ar: "تمت إضافة \"\(task)\" إلى \(categoryTitle)"
        )
    }

    static var openProfileLabel: String {
        pick(en: "Open profile", ur: "پروفائل کھولیں", ar: "فتح الملف الشخصي")
    }

    static var defaultFirstName: String {
        pick(en: "Student", ur: "طالب علم", ar: "طالب")
    }

    static var sponsoredBadge: String {
        pick(en: "Sponsored", ur: "سپانسرڈ", ar: "ممول")
    }

    static var sponsoredTitle: String {
        pick(en: "Student SIM Offers", ur: "اسٹوڈنٹ SIM آفرز", ar: "عروض شرائح الطلاب")
    }

    static var sponsoredSubtitle: String {
        pick(
            en: "Compare \(destinationCode) plans tailored for students.",
            ur: "طلبا کے لیے \(destinationCode) پلانز کا موازنہ کریں۔",
            ar: "قارن خطط \(destinationName) المصممة للطلاب."
        )
    }

    static var sponsoredCTA: String {
        pick(en: "View", ur: "دیکھیں", ar: "عرض")
    }

    static var sponsoredAccessibilityLabel: String {
        pick(
            en: "Sponsored: student SIM offers",
            ur: "سپانسرڈ: طلبا کے لیے SIM آفرز",
            ar: "ممول: عروض شرائح للطلاب"
        )
    }

    static var sponsoredAccessibilityHint: String {
        pick(
            en: "Opens partner offers in the in-app browser",
            ur: "ایپ کے اندر پارٹنر آفرز کھولتا ہے",
            ar: "يفتح عروض الشريك داخل المتصفح"
        )
    }

    static var quickAddActionLabel: String {
        pick(en: "Quick add task", ur: "فوری ٹاسک شامل کریں", ar: "إضافة مهمة سريعة")
    }

    static var quickAddHereLabel: String {
        pick(en: "Quick Add Here", ur: "یہیں فوری اضافہ", ar: "إضافة سريعة هنا")
    }

    static var openCategoryActionLabel: String {
        pick(en: "Open category", ur: "کیٹیگری کھولیں", ar: "فتح الفئة")
    }

    static var openLabel: String {
        pick(en: "Open", ur: "کھولیں", ar: "فتح")
    }

    static var addLabel: String {
        pick(en: "Add", ur: "شامل کریں", ar: "إضافة")
    }

    static var categoryCardHint: String {
        pick(
            en: "Double tap to view tasks. Swipe toward the edge for quick actions.",
            ur: "ٹاسکس دیکھنے کے لیے ڈبل ٹیپ کریں۔ فوری ایکشنز کے لیے کنارے کی طرف سوائپ کریں۔",
            ar: "انقر مرتين لعرض المهام. اسحب نحو الحافة لإجراءات سريعة."
        )
    }

    static var scrollForMore: String {
        pick(
            en: "Scroll for more",
            ur: "مزید کے لیے اسکرول کریں",
            ar: "مرر للمزيد"
        )
    }

    static var emptyStateTitle: String {
        pick(
            en: "Nothing left right now",
            ur: "ابھی کچھ باقی نہیں",
            ar: "لا شيء متبقٍ الآن"
        )
    }

    static var emptyStateMessage: String {
        pick(
            en: "Pull to refresh or add a personal task from the header plus button.",
            ur: "ریفریش کے لیے نیچے کھینچیں یا ہیڈر کے پلس بٹن سے ذاتی ٹاسک شامل کریں۔",
            ar: "اسحب للتحديث أو أضف مهمة شخصية من زر الإضافة في العنوان."
        )
    }

    static var emptyStateAccessibilityLabel: String {
        pick(
            en: "No categories available right now",
            ur: "فی الحال کوئی کیٹیگری دستیاب نہیں",
            ar: "لا توجد فئات متاحة الآن"
        )
    }

    static func categoryAccessibilityLabel(
        title: String,
        completedCount: Int,
        totalCount: Int
    ) -> String {
        let completed = localizedNumber(completedCount)
        let total = localizedNumber(totalCount)
        return pick(
            en: "\(title). \(completed) of \(total) tasks completed.",
            ur: "\(title)۔ \(total) میں سے \(completed) کام مکمل۔",
            ar: "\(title). تم إكمال \(completed) من \(total) مهام."
        )
    }

    static func taskProgressLine(completedCount: Int, totalCount: Int) -> String {
        let completed = localizedNumber(completedCount)
        let total = localizedNumber(totalCount)
        return pick(
            en: "\(completed) of \(total) tasks",
            ur: "\(total) میں سے \(completed) کام",
            ar: "\(completed) من \(total) مهام"
        )
    }

    static func taskProgressCompact(completedCount: Int, totalCount: Int) -> String {
        let completed = localizedNumber(completedCount)
        let total = localizedNumber(totalCount)
        return "\(completed)/\(total)"
    }

    static var categoryCompleteLine: String {
        pick(
            en: "Complete ✓",
            ur: "مکمل ✓",
            ar: "مكتمل ✓"
        )
    }

    static var startHereBadge: String {
        pick(
            en: "Start Here",
            ur: "یہاں سے شروع کریں",
            ar: "ابدأ هنا"
        )
    }

    static var startHereHint: String {
        pick(
            en: "Recommended first category",
            ur: "شروع کرنے کے لیے تجویز کردہ کیٹیگری",
            ar: "الفئة المقترحة للبدء"
        )
    }

    static func tasksCount(_ count: Int) -> String {
        let value = localizedNumber(count)
        return pick(
            en: "\(value) tasks",
            ur: "\(value) کام",
            ar: "\(value) مهام"
        )
    }

    static var preDepartureChecklistTitle: String {
        pick(
            en: "Pre-Departure Checklist",
            ur: "روانگی سے پہلے کی فہرست",
            ar: "قائمة ما قبل المغادرة"
        )
    }

    static func categoryDisplayTitle(categoryID: String, fallbackTitle: String) -> String {
        guard let category = AppCategory.resolve(categoryID: categoryID, fallbackTitle: fallbackTitle) else {
            return fallbackTitle
        }

        switch category {
        case .beforeArrival:
            return preDepartureChecklistTitle
        default:
            return category.title
        }
    }

    static func categoryDisplaySubtitle(
        categoryID: String,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) -> String {
        guard let category = AppCategory.resolve(categoryID: categoryID, fallbackTitle: fallbackTitle) else {
            return fallbackSubtitle
        }
        return category.subtitle
    }
}

struct StartupPlaceholderView: View {
    let primaryMetric: String

    var body: some View {
        VStack(spacing: Theme.spaceL) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                Text("Arrival UK")
                    .font(ArrivalTypography.figtree(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text(primaryMetric)
                    .font(ArrivalTypography.figtree(size: 15, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.spaceL)

            ProgressView("Loading your checklist…")
                .progressViewStyle(.circular)
                .font(ArrivalTypography.figtree(size: 14, weight: .medium))
                .tint(Theme.brandPrimary)
                .foregroundStyle(Theme.secondaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.spaceL)
        .padding(.vertical, Theme.spaceL)
    }
}

struct HeaderView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let currentDate: Date
    let arrivalDate: Date
    let userDisplayName: String
    let adaptiveMessage: String
    let streakCount: Int
    let onSearchTap: () -> Void
    let onAddTap: () -> Void
    let onProfileTap: () -> Void

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        return HomeLocalization.greeting(for: hour)
    }

    private var dateBadgeText: String {
        UKLocaleFormat.mediumDateString(currentDate)
    }

    private var greetingLine: String {
        "\(greetingText), \(userFirstName)"
    }

    private var userFirstName: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return HomeLocalization.defaultFirstName }
        return trimmed.components(separatedBy: .whitespaces).first ?? trimmed
    }

    private var dateContextLine: String {
        dateBadgeText
    }

    private var arrivalStatusPillText: String? {
        if daysUntilArrival == 0 {
            return HomeLocalization.arrivingToday
        }
        if daysUntilArrival == 1 {
            return HomeLocalization.arrivingTomorrow
        }
        if (2...14).contains(daysUntilArrival) {
            return HomeLocalization.arrivingInDays(daysUntilArrival)
        }
        return nil
    }

    private var streakPillText: String? {
        guard streakCount > 0 else { return nil }
        return HomeLocalization.streakLabel(days: streakCount)
    }

    private var profileInitials: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "U" }

        let parts = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            let combined = "\(first)\(last)".uppercased()
            return combined.isEmpty ? "U" : combined
        }

        if let first = trimmed.first {
            return String(first).uppercased()
        }

        return "U"
    }

    private var daysUntilArrival: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        let arrival = calendar.startOfDay(for: arrivalDate)
        return calendar.dateComponents([.day], from: today, to: arrival).day ?? 0
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.95) : Theme.primaryText
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : Theme.secondaryText
    }

    private var buttonStrokeColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(colorSchemeContrast == .increased ? 0.35 : 0.22)
        }
        return Theme.stroke
    }

    private var headerBorderColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(colorSchemeContrast == .increased ? 0.30 : 0.18)
        }
        return Color.white.opacity(0.30)
    }

    private var headerShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.34) : Theme.shadowSoft.opacity(0.78)
    }

    private var headerShadowRadius: CGFloat {
        colorScheme == .dark ? 18 : 12
    }

    private var headerShadowY: CGFloat {
        colorScheme == .dark ? 8 : 5
    }

    private var headerBackgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Theme.navy900.opacity(0.92), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.95), Theme.backgroundPrimary.opacity(0.90)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var headerGradientOpacity: Double {
        colorScheme == .dark ? 0.74 : 0.62
    }

    private var headerGlassHighlightOpacity: Double {
        colorScheme == .dark ? 0.06 : 0.32
    }

    private var headerSurfaceFillColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(colorSchemeContrast == .increased ? 0.10 : 0.07)
        }
        return Color.white.opacity(colorSchemeContrast == .increased ? 0.92 : 0.86)
    }

    private var controlShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.30) : Theme.shadowSoft.opacity(0.70)
    }

    private var controlBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(colorSchemeContrast == .increased ? 0.16 : 0.12)
        }
        return Color.white.opacity(colorSchemeContrast == .increased ? 0.94 : 0.88)
    }

    private var controlSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 52 : 46
    }

    private var titleShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color.black.opacity(0.10)
    }

    private var profileAccessibilityLabel: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return HomeLocalization.openProfileLabel
        }
        return "\(HomeLocalization.openProfileLabel): \(trimmed)"
    }

    @ViewBuilder
    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Arrival UK")
                .font(ArrivalTypography.figtree(size: 12, weight: .semibold))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(secondaryTextColor.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text(greetingLine)
                .font(ArrivalTypography.figtree(size: 30, weight: .black))
                .tracking(-1.2)
                .foregroundStyle(primaryTextColor)
                .shadow(color: titleShadowColor, radius: 1, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text(dateContextLine)
                .font(ArrivalTypography.figtree(size: 11, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.90)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text(HomeLocalization.journeyTagline)
                .font(ArrivalTypography.figtree(size: 12, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.90)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Text(adaptiveMessage)
                .font(ArrivalTypography.figtree(size: 12, weight: .medium))
                .foregroundStyle(secondaryTextColor.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            if let streakText = streakPillText {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(streakText)
                        .font(ArrivalTypography.figtree(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.luxuryGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.luxuryGold.opacity(0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.luxuryGold.opacity(0.25), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(streakText)
            }

            if let pillText = arrivalStatusPillText {
                HStack(spacing: 8) {
                    Image(systemName: "airplane.arrival")
                        .font(.system(size: 13, weight: .semibold))

                    Text(pillText)
                        .font(ArrivalTypography.figtree(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.brandPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.brandPrimary.opacity(0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.brandPrimary.opacity(0.20), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(pillText)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                Haptics.selectionIfAllowed()
                onSearchTap()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .frame(width: controlSize, height: controlSize)
                    .background(Circle().fill(controlBackgroundColor))
                    .overlay(Circle().stroke(buttonStrokeColor, lineWidth: colorSchemeContrast == .increased ? 1.5 : 1))
                    .shadow(color: controlShadowColor, radius: 5, x: 0, y: 2)
            }
            .buttonStyle(AppFastButtonStyle())
            .accessibilityLabel(HomeLocalization.searchTasksLabel)

            Button {
                Haptics.selectionIfAllowed()
                onAddTap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.inverseText)
                    .frame(width: controlSize, height: controlSize)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.actionGradientStart, Theme.actionGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.32), lineWidth: 1))
                    .shadow(color: Theme.luxuryGold.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(AppFastButtonStyle())
            .accessibilityLabel(HomeLocalization.addTaskLabel)
            .accessibilityHint(HomeLocalization.addTaskHint)

            Button {
                Haptics.selectionIfAllowed()
                onProfileTap()
            } label: {
                Text(profileInitials)
                    .font(ArrivalTypography.figtree(size: 17, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: controlSize, height: controlSize)
                    .background(
                        Circle()
                            .fill(controlBackgroundColor)
                            .overlay(
                                Circle()
                                    .stroke(buttonStrokeColor, lineWidth: 1.5)
                            )
                    )
                    .shadow(color: controlShadowColor.opacity(0.55), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(AppFastButtonStyle())
            .accessibilityLabel(profileAccessibilityLabel)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            if usesAccessibilityLayout {
                identityBlock

                actionButtons
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: Theme.spaceM) {
                    identityBlock

                    Spacer(minLength: Theme.spaceS)

                    actionButtons
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.spaceL)
        .padding(.vertical, Theme.spaceM)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .fill(headerSurfaceFillColor)
                .overlay(headerBackgroundGradient.opacity(headerGradientOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .fill(Color.white.opacity(headerGlassHighlightOpacity))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .stroke(headerBorderColor, lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
        )
        .shadow(color: headerShadowColor, radius: headerShadowRadius, x: 0, y: headerShadowY)
    }
}

struct HomeTimelineHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String
    var progressLabel: String? = nil
    var isCollapsible: Bool = false
    var isCollapsed: Bool = false
    var onToggleCollapse: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Theme.spaceS) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(ArrivalTypography.figtree(size: 8.5, weight: .bold))
                    .tracking(1.87)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.94) : Theme.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.9)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(ArrivalTypography.figtree(size: 12, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.70) : Theme.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: Theme.spaceS)

            if isCollapsible, let onToggleCollapse {
                Button(action: onToggleCollapse) {
                    HStack(spacing: 6) {
                        if let progressLabel {
                            Text(progressLabel)
                                .font(ArrivalTypography.figtree(size: 9.5, weight: .semibold))
                        }

                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.80) : Theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Theme.card)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        colorScheme == .dark ? Color.white.opacity(colorSchemeContrast == .increased ? 0.28 : 0.18) : Theme.stroke,
                                        lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                                    )
                            )
                    )
                }
                .buttonStyle(AppFastButtonStyle())
                .accessibilityLabel(
                    isCollapsed
                        ? HomeLocalization.expandCompletedSection
                        : HomeLocalization.collapseCompletedSection
                )
                .accessibilityHint(HomeLocalization.completedSectionToggleHint)
            } else if let progressLabel {
                Text(progressLabel)
                    .font(ArrivalTypography.figtree(size: 9.5, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Theme.card)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        colorScheme == .dark ? Color.white.opacity(colorSchemeContrast == .increased ? 0.28 : 0.18) : Theme.stroke,
                                        lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                                    )
                            )
                    )
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

struct HomeTimelineFilterBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let filters: [HomeTimelineFilterOption]
    let selectedFilterID: String
    let onSelectFilter: (HomeTimelineFilterOption) -> Void

    private var chipTrackBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
    }

    private var chipSelectedForeground: Color {
        colorScheme == .dark ? Theme.inverseText : Theme.primaryText
    }

    private var chipUnselectedForeground: Color {
        colorScheme == .dark ? Color.white.opacity(0.86) : Theme.secondaryText
    }

    private var chipBorderOpacity: Double {
        colorSchemeContrast == .increased ? 0.34 : 0.18
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    let isSelected = selectedFilterID == filter.id
                    Button {
                        onSelectFilter(filter)
                    } label: {
                        Text(filter.title)
                            .font(ArrivalTypography.figtree(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? chipSelectedForeground : chipUnselectedForeground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        isSelected
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [Theme.actionGradientStart, Theme.actionGradientEnd],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            : AnyShapeStyle(chipTrackBackground)
                                    )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        isSelected
                                            ? Color.clear
                                            : (colorScheme == .dark ? Color.white : Color.black).opacity(chipBorderOpacity),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(AppFastButtonStyle())
                    .accessibilityLabel(
                        isSelected
                            ? HomeLocalization.filterSelectedA11y(filter.title)
                            : filter.title
                    )
                }
            }
            .padding(.horizontal, Theme.spaceL)
        }
        .contentMargins(.vertical, 2, for: .scrollContent)
    }
}

struct HomeTimelineFilterOption: Identifiable, Hashable {
    let id: String
    let title: String
}

struct HomeSponsoredSlotView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var onImpression: (() -> Void)? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.spaceM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(HomeLocalization.sponsoredBadge)
                        .font(ArrivalTypography.figtree(size: 11, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : Theme.secondaryText)
                        .textCase(.uppercase)

                    Text(HomeLocalization.sponsoredTitle)
                        .font(ArrivalTypography.figtree(size: 16, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : Theme.primaryText)

                    Text(HomeLocalization.sponsoredSubtitle)
                        .font(ArrivalTypography.figtree(size: 13, weight: .regular))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.74) : Theme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: Theme.spaceS)

                HStack(spacing: 6) {
                    Text(HomeLocalization.sponsoredCTA)
                        .font(ArrivalTypography.figtree(size: 13, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(colorScheme == .dark ? Theme.primaryLight : Theme.linkText)
            }
            .padding(Theme.spaceM)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(colorSchemeContrast == .increased ? 0.30 : 0.18) : Theme.stroke,
                                lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                            )
                    )
            )
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.24) : Theme.shadowSoft, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(AppFastButtonStyle())
        .accessibilityLabel(HomeLocalization.sponsoredAccessibilityLabel)
        .accessibilityHint(HomeLocalization.sponsoredAccessibilityHint)
        .onAppear {
            onImpression?()
        }
    }
}

struct HomeEmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(spacing: Theme.spaceM) {
            Image(systemName: "checklist")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.76) : Theme.secondaryText)

            Text(HomeLocalization.emptyStateTitle)
                .font(ArrivalTypography.figtree(size: 17, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : Theme.primaryText)

            Text(HomeLocalization.emptyStateMessage)
                .font(ArrivalTypography.figtree(size: 14, weight: .regular))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.spaceL)
        .padding(.vertical, Theme.spaceXL)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(colorSchemeContrast == .increased ? 0.30 : 0.18) : Theme.stroke,
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(HomeLocalization.emptyStateAccessibilityLabel)
    }
}

struct PressFeedbackButtonStyle: ButtonStyle {
    let prefersReducedMotion: Bool

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
