import Foundation

enum SampleData {
    static let categories: [ChecklistCategory] = [
        ChecklistCategory(
            id: "before_arrival",
            title: "Before Arrival",
            subtitle: "Must complete before landing",
            icon: "airplane.departure",
            priorityLevel: .critical,
            urgency: .immediate,
            tasks: [
                ChecklistTask(
                    id: "before_visa_check",
                    title: "Confirm visa documents are complete",
                    detail: "Double-check passport validity, CAS details, and proof of funds before travel.",
                    timing: .monthBeforeArrival,
                    priority: .mustDo,
                    sourceTitle: "UK Student Visa Guidance (GOV.UK)",
                    sourceURL: "https://www.gov.uk/student-visa"
                ),
                ChecklistTask(
                    id: "before_uni_letter",
                    title: "Download university status letter template",
                    detail: "Prepare a digital copy so bank account and admin steps are faster after arrival.",
                    timing: .weekBeforeArrival,
                    priority: .shouldDo
                ),
                ChecklistTask(
                    id: "before_housing_docs",
                    title: "Prepare housing and ID document pack",
                    detail: "Keep tenancy agreement, passport, visa proof, and offer letter in one folder.",
                    timing: .weekBeforeArrival,
                    priority: .mustDo
                ),
                ChecklistTask(
                    id: "before_budget",
                    title: "Set first-month budget",
                    detail: "Estimate rent, groceries, transport, and emergency spending for your first month.",
                    timing: .weekBeforeArrival,
                    priority: .shouldDo
                )
            ]
        ),
        ChecklistCategory(
            id: "health_admin",
            title: "Health & Admin",
            subtitle: "Important for your first week",
            icon: "heart.text.square",
            priorityLevel: .high,
            urgency: .week1,
            tasks: [
                ChecklistTask(
                    id: "health_gp",
                    title: "Register with a GP surgery",
                    detail: "Do this soon after settling so healthcare access is ready when needed.",
                    timing: .firstWeek,
                    priority: .mustDo,
                    sourceTitle: "How to Register with a GP (NHS)",
                    sourceURL: "https://www.nhs.uk/nhs-services/gps/how-to-register-with-a-gp-surgery/"
                ),
                ChecklistTask(
                    id: "health_ni",
                    title: "Apply for National Insurance number",
                    detail: "Needed for legal employment and correct tax setup in part-time or full-time work.",
                    timing: .firstMonth,
                    priority: .mustDo,
                    sourceTitle: "Apply for a National Insurance Number (GOV.UK)",
                    sourceURL: "https://www.gov.uk/apply-national-insurance-number"
                ),
                ChecklistTask(
                    id: "health_council_tax",
                    title: "Submit council tax student exemption",
                    detail: "Use your student proof to avoid paying full council tax where eligible.",
                    timing: .firstMonth,
                    priority: .shouldDo,
                    sourceTitle: "Council Tax Discounts for Students (GOV.UK)",
                    sourceURL: "https://www.gov.uk/council-tax/discounts-for-full-time-students"
                )
            ]
        ),
        ChecklistCategory(
            id: "money_banking",
            title: "Money & Banking",
            subtitle: "Money setup and daily essentials",
            icon: "banknote",
            priorityLevel: .medium,
            urgency: .week1,
            tasks: [
                ChecklistTask(
                    id: "money_open_account",
                    title: "Open a UK bank account",
                    detail: "Compare student accounts and keep your enrollment letter ready for verification.",
                    timing: .firstWeek,
                    priority: .mustDo
                ),
                ChecklistTask(
                    id: "money_alerts",
                    title: "Enable spending alerts and limits",
                    detail: "Turn on transaction notifications to avoid overspending during early setup weeks.",
                    timing: .firstWeek,
                    priority: .shouldDo
                ),
                ChecklistTask(
                    id: "money_emergency_buffer",
                    title: "Create a small emergency buffer",
                    detail: "Aim for a minimum reserve so unexpected transport or medical costs are covered.",
                    timing: .firstMonth,
                    priority: .optional
                )
            ]
        ),
        ChecklistCategory(
            id: "travel_discounts",
            title: "Travel & Discounts",
            subtitle: "Important for your first week",
            icon: "tram",
            priorityLevel: .low,
            urgency: .anytime,
            tasks: [
                ChecklistTask(
                    id: "travel_railcard",
                    title: "Buy a 16-25 Railcard (if eligible)",
                    detail: "Can reduce train fares significantly during term and holiday travel.",
                    timing: .firstMonth,
                    priority: .shouldDo,
                    sourceTitle: "16-25 Railcard",
                    sourceURL: "https://www.16-25railcard.co.uk/"
                ),
                ChecklistTask(
                    id: "travel_local_pass",
                    title: "Check local student transport pass",
                    detail: "Many cities offer discounted bus or metro options for students.",
                    timing: .firstMonth,
                    priority: .shouldDo
                ),
                ChecklistTask(
                    id: "travel_route_setup",
                    title: "Save key routes in transport apps",
                    detail: "Pre-save campus, accommodation, supermarket, and nearest hospital routes.",
                    timing: .firstWeek,
                    priority: .optional
                )
            ]
        )
    ]
}
