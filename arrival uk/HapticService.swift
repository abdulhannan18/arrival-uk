import UIKit

protocol HapticServiceProtocol {
    func light()
    func soft()
    func medium()
    func heavy()
    func prepare()
}

final class HapticService: HapticServiceProtocol {
    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let softGen = UIImpactFeedbackGenerator(style: .soft)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)

    static let shared = HapticService()

    private init() {}

    func prepare() {
        lightGen.prepare()
        softGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
    }

    func light() {
        lightGen.prepare()
        lightGen.impactOccurred()
    }

    func soft() {
        softGen.prepare()
        softGen.impactOccurred()
    }

    func medium() {
        mediumGen.prepare()
        mediumGen.impactOccurred()
    }

    func heavy() {
        heavyGen.prepare()
        heavyGen.impactOccurred()
    }
}
