import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct EmergencyContactItem: Identifiable {
    let id: String
    let name: String
    let number: String
    let detail: String
    let symbol: String
    let tint: Color
    let emergency: Bool
}

@available(iOS 17.0, *)
struct EmergencyContactsSheet: View {
    var onClose: (() -> Void)? = nil

    private let contacts: [EmergencyContactItem] = [
        EmergencyContactItem(
            id: "999",
            name: "Emergency Services",
            number: "999",
            detail: "Police, Fire, Ambulance",
            symbol: "exclamationmark.triangle.fill",
            tint: .red,
            emergency: true
        ),
        EmergencyContactItem(
            id: "111",
            name: "NHS Non-Emergency",
            number: "111",
            detail: "24/7 urgent medical advice",
            symbol: "cross.case.fill",
            tint: .blue,
            emergency: false
        ),
        EmergencyContactItem(
            id: "101",
            name: "Police Non-Emergency",
            number: "101",
            detail: "Report non-urgent incidents",
            symbol: "shield.fill",
            tint: .indigo,
            emergency: false
        ),
        EmergencyContactItem(
            id: "116123",
            name: "Samaritans",
            number: "116123",
            detail: "Emotional support and crisis line",
            symbol: "heart.fill",
            tint: .green,
            emergency: false
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Emergency Contacts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            List {
                Section {
                    Text("For life-threatening emergencies, call 999 immediately.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 4)
                }

                let emergencyContacts = contacts.filter(\.emergency)
                if !emergencyContacts.isEmpty {
                    Section("Emergency") {
                        ForEach(emergencyContacts) { contact in
                            contactRow(contact)
                        }
                    }
                }

                let supportContacts = contacts.filter { !$0.emergency }
                if !supportContacts.isEmpty {
                    Section("Support") {
                        ForEach(supportContacts) { contact in
                            contactRow(contact)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.card)
        }
        .background(Theme.card)
    }

    @ViewBuilder
    private func contactRow(_ contact: EmergencyContactItem) -> some View {
        Button {
            call(number: contact.number)
        } label: {
            HStack(spacing: Theme.spaceS) {
                Image(systemName: contact.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(contact.tint)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text("\(contact.number) • \(contact.detail)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: Theme.spaceXS)

                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(contact.tint)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func call(number: String) {
        guard let url = URL(string: "tel://\(number)"),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func close() {
        onClose?()
    }
}
