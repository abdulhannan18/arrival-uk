import Foundation

@available(iOS 17.0, *)
func makeTaskSyncSessionConfiguration(for timeout: TaskSyncRequestTimeouts) -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    // URLSession does not expose a separate connect-only timeout, so use the
    // full request budget as the effective transport cap and fail fast on reachability.
    configuration.timeoutIntervalForRequest = timeout.requestTimeout
    configuration.timeoutIntervalForResource = timeout.requestTimeout
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.waitsForConnectivity = false
    return configuration
}
