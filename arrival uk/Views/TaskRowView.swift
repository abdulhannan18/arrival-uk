import SwiftUI
import UIKit

struct PremiumRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed else { return }
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.impactOccurred()
            }
    }
}

struct TaskRowView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var task: CategoryTask
    let accentColor: Color
    let dotColor: Color
    let isFeatured: Bool
    var onToggle: () -> Void
    var onOpenGuide: () -> Void
    var heroNamespace: Namespace.ID? = nil
    var isHeroSource: Bool = true
    var isHiddenForHero: Bool = false

    private var taskDescription: String? {
        guard let detail = task.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty else {
            return nil
        }
        return detail
    }

    private var hasGuideContent: Bool {
        !task.guideSteps.isEmpty ||
        task.content != nil ||
        task.taskDetailContent != nil ||
        task.sourceURL?.isEmpty == false ||
        task.officialSourceURL?.isEmpty == false
    }

    private var taskNameColor: Color {
        if task.isCompleted {
            return colorScheme == .dark ? Color.white.opacity(0.36) : Color.black.opacity(0.42)
        }
        return colorScheme == .dark ? .white : Color.primary
    }

    private var taskDescriptionColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.52) : Color.black.opacity(0.58)
    }

    private var taskMetaColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.42) : Color.black.opacity(0.46)
    }

    private var rowBackground: Color {
        if colorScheme == .dark {
            return Color.white.opacity(primaryActionOpensGuide ? 0.08 : 0.02)
        }
        return Color.black.opacity(primaryActionOpensGuide ? 0.045 : 0.015)
    }

    private var checkboxStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.26) : Color.black.opacity(0.18)
    }

    private var primaryActionOpensGuide: Bool {
        !task.isCompleted && hasGuideContent
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Button {
                    triggerPrimaryAction()
                } label: {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(rowBackground)
                            .heroMatchedGeometry(
                                id: "task-row-bg-\(task.id)",
                                in: heroNamespace,
                                isSource: isHeroSource
                            )

                        GeometryReader { proxy in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(primaryActionOpensGuide ? 0.36 : 0),
                                            Color.purple.opacity(primaryActionOpensGuide ? 0.14 : 0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(
                                    width: max(proxy.size.height * 1.3, 128),
                                    height: max(proxy.size.height * 1.3, 128)
                                )
                                .offset(x: proxy.size.width * 0.62, y: -proxy.size.height * 0.42)
                                .heroMatchedGeometry(
                                    id: "task-row-orb-\(task.id)",
                                    in: heroNamespace,
                                    isSource: isHeroSource
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        HStack(alignment: .center, spacing: 12) {
                            checkboxIcon

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(taskNameColor)
                                    .strikethrough(task.isCompleted, color: taskMetaColor)
                                    .heroMatchedGeometry(
                                        id: "task-row-title-\(task.id)",
                                        in: heroNamespace,
                                        isSource: isHeroSource
                                    )

                                if !task.isCompleted, let taskDescription {
                                    Text(taskDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(taskDescriptionColor)
                                        .lineLimit(isFeatured ? 3 : 2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .heroMatchedGeometry(
                                            id: "task-row-subtitle-\(task.id)",
                                            in: heroNamespace,
                                            isSource: isHeroSource
                                        )
                                }

                                if !task.isCompleted {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(dotColor)
                                            .frame(width: 4, height: 4)
                                            .opacity(0.75)

                                        Text(task.timingText)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(taskMetaColor)
                                    }
                                    .padding(.top, 1)
                                }
                            }

                            Spacer(minLength: 12)

                            if primaryActionOpensGuide {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(taskMetaColor)
                                    .padding(.trailing, 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
                .buttonStyle(PremiumRowButtonStyle())
                .hoverEffect(.lift)
                .accessibilityLabel(task.title)
                .accessibilityHint(primaryActionOpensGuide ? "Open task guide" : "Toggle completion")

                Button {
                    triggerToggle()
                } label: {
                    checkboxIcon
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)
                .opacity(primaryActionOpensGuide ? 1 : 0)
                .allowsHitTesting(primaryActionOpensGuide)
            }
            .contentShape(Rectangle())

            if !isHiddenForHero {
                Divider()
                    .padding(.leading, 60)
            } else {
                Divider()
                    .opacity(0)
            }
        }
        .opacity(isHiddenForHero ? 0.001 : (task.isCompleted ? 0.58 : 1))
        .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.30), value: task.isCompleted)
        .accessibilityElement(children: .combine)
        .allowsHitTesting(!isHiddenForHero)
    }

    private var checkboxIcon: some View {
        ZStack {
            Circle()
                .strokeBorder(task.isCompleted ? accentColor : checkboxStrokeColor, lineWidth: 2)
                .background(
                    Circle()
                        .fill(task.isCompleted ? accentColor : Color.clear)
                )
                .frame(width: 24, height: 24)

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .opacity(task.isCompleted ? 1 : 0)
        }
        .accessibilityHidden(true)
    }

    private func triggerPrimaryAction() {
        if primaryActionOpensGuide {
            HapticService.shared.light()
            onOpenGuide()
        } else {
            triggerToggle()
        }
    }

    private func triggerToggle() {
        if task.isCompleted {
            HapticService.shared.light()
        } else {
            HapticService.shared.medium()
        }
        onToggle()
    }
}

private extension View {
    @ViewBuilder
    func heroMatchedGeometry(id: String, in namespace: Namespace.ID?, isSource: Bool) -> some View {
        if let namespace {
            matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            self
        }
    }
}
