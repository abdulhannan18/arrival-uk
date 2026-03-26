import Foundation

enum ContentExternalURLRoute: Equatable {
    case presentInApp
    case discard

    static func resolve(for url: URL) -> ContentExternalURLRoute {
        ExternalURLPolicy.isAllowed(url) ? .presentInApp : .discard
    }
}
