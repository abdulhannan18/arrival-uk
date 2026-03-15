#!/usr/bin/swift
import Foundation

enum Severity: String {
    case warning = "WARNING"
    case error = "ERROR"
}

struct Issue {
    let severity: Severity
    let path: String
    let message: String
}

enum Validator {
    private static let trustedOfficialDomainSuffixes: [String] = [
        "gov.uk",
        "ac.uk",
        "nhs.uk",
        "nationalrail.co.uk",
        "ukri.org.uk",
        "ukfinance.org.uk",
        "ukcisa.org.uk",
        "hsbc.co.uk",
        "lloydsbank.com",
        "aldi.co.uk",
        "tesco.com",
        "studentbeans.com",
        "totum.com"
    ]

    static func validate(data: Data, fileName: String) -> [Issue] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any]
        else {
            return [Issue(severity: .error, path: fileName, message: "Invalid JSON document.")]
        }

        guard let categories = root["categories"] as? [[String: Any]] else {
            return [Issue(severity: .error, path: "\(fileName).categories", message: "Missing categories array.")]
        }

        if categories.isEmpty {
            return [Issue(severity: .error, path: "\(fileName).categories", message: "Categories array is empty.")]
        }

        var issues: [Issue] = []
        var categoryIDs: Set<String> = []

        for (categoryIndex, category) in categories.enumerated() {
            let categoryPath = "categories[\(categoryIndex)]"
            let categoryID = (category["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryTitle = (category["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryIcon = (category["icon"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if categoryID.isEmpty {
                issues.append(Issue(severity: .error, path: "\(categoryPath).id", message: "Category id is empty."))
            } else if categoryIDs.contains(categoryID) {
                issues.append(Issue(severity: .error, path: "\(categoryPath).id", message: "Duplicate category id '\(categoryID)'."))
            } else {
                categoryIDs.insert(categoryID)
            }

            if categoryTitle.isEmpty {
                issues.append(Issue(severity: .error, path: "\(categoryPath).title", message: "Category title is empty."))
            }

            if categoryIcon.isEmpty {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).icon", message: "Category icon is empty."))
            }

            if let deadline = category["deadline"] as? String, !deadline.isEmpty, !isValidDate(deadline) {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).deadline", message: "Deadline is not ISO date (yyyy-MM-dd)."))
            }

            guard let tasks = category["tasks"] as? [[String: Any]] else {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).tasks", message: "Missing tasks array."))
                continue
            }

            if tasks.isEmpty {
                issues.append(Issue(severity: .warning, path: "\(categoryPath).tasks", message: "Category has no tasks."))
            }

            var taskIDs: Set<String> = []
            for (taskIndex, task) in tasks.enumerated() {
                let taskPath = "\(categoryPath).tasks[\(taskIndex)]"
                let taskID = (task["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let taskTitle = (task["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if taskID.isEmpty {
                    issues.append(Issue(severity: .error, path: "\(taskPath).id", message: "Task id is empty."))
                } else if taskIDs.contains(taskID) {
                    issues.append(Issue(severity: .error, path: "\(taskPath).id", message: "Duplicate task id '\(taskID)'."))
                } else {
                    taskIDs.insert(taskID)
                }

                if taskTitle.isEmpty {
                    issues.append(Issue(severity: .error, path: "\(taskPath).title", message: "Task title is empty."))
                }

                collectURLIssues(
                    in: task,
                    path: taskPath,
                    issues: &issues,
                    inheritedTrustType: nil
                )
            }
        }

        return issues
    }

    private static func collectURLIssues(
        in node: Any,
        path: String,
        issues: inout [Issue],
        inheritedTrustType: String?
    ) {
        if let dictionary = node as? [String: Any] {
            let localTrustType = dictionary["sourceType"] as? String
                ?? ((dictionary["source"] as? [String: Any])?["sourceType"] as? String)
                ?? inheritedTrustType

            if let urlString = dictionary["url"] as? String {
                validateURL(
                    urlString,
                    path: "\(path).url",
                    issues: &issues,
                    trustType: localTrustType
                )
            }

            for (key, value) in dictionary {
                collectURLIssues(
                    in: value,
                    path: "\(path).\(key)",
                    issues: &issues,
                    inheritedTrustType: localTrustType
                )
            }

            return
        }

        if let array = node as? [Any] {
            for (index, item) in array.enumerated() {
                collectURLIssues(
                    in: item,
                    path: "\(path)[\(index)]",
                    issues: &issues,
                    inheritedTrustType: inheritedTrustType
                )
            }
        }
    }

    private static func validateURL(
        _ raw: String,
        path: String,
        issues: inout [Issue],
        trustType: String?
    ) {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else {
            issues.append(Issue(severity: .error, path: path, message: "Invalid URL '\(raw)'."))
            return
        }

        if scheme != "https" && scheme != "http" {
            issues.append(Issue(severity: .error, path: path, message: "Unsupported URL scheme '\(scheme)'."))
            return
        }

        guard let trustType else { return }
        let lowered = trustType.lowercased()
        guard lowered == "official" || lowered == "university" else { return }

        guard let host = url.host?.lowercased() else {
            issues.append(Issue(severity: .warning, path: path, message: "Official/university URL missing host."))
            return
        }

        let isTrusted = trustedOfficialDomainSuffixes.contains(where: { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
        })

        if !isTrusted {
            issues.append(
                Issue(
                    severity: .warning,
                    path: path,
                    message: "Official/university host '\(host)' is not in trusted suffix list."
                )
            )
        }
    }

    private static func isValidDate(_ raw: String) -> Bool {
        isoDateFormatter.date(from: raw) != nil || fallbackDateFormatter.date(from: raw) != nil
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

let args = CommandLine.arguments.dropFirst()
let files: [String]
if args.isEmpty {
    files = ["arrival uk/Data/categories.json", "arrival uk/Data/content.json"]
} else {
    files = Array(args)
}

var totalWarnings = 0
var totalErrors = 0

for file in files {
    guard let data = FileManager.default.contents(atPath: file) else {
        fputs("ERROR \(file): Could not read file.\n", stderr)
        totalErrors += 1
        continue
    }

    let issues = Validator.validate(data: data, fileName: file)
    let warnings = issues.filter { $0.severity == .warning }
    let errors = issues.filter { $0.severity == .error }

    totalWarnings += warnings.count
    totalErrors += errors.count

    print("Validation: \(file)")
    print("  warnings: \(warnings.count)")
    print("  errors: \(errors.count)")
    for issue in issues.prefix(120) {
        print("  [\(issue.severity.rawValue)] \(issue.path): \(issue.message)")
    }
}

if totalErrors > 0 {
    exit(1)
}
exit(0)
