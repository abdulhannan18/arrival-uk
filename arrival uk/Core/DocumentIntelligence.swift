import Foundation
import OSLog
import UIKit
import Vision

struct DocumentClassificationResult {
    let type: SecureDocType
    let confidence: Double
    let requestRevision: Int
}

final class DocumentIntelligence {
    static let shared = DocumentIntelligence()

    private typealias KeywordSignature = (type: SecureDocType, keywords: [String])
    private static let signatures: [KeywordSignature] = [
        (
            .studentVisa,
            [
                "biometric residence permit",
                "residence permit",
                "brp",
                "leave to remain",
                "ukvi",
                "entry clearance",
                "visa"
            ]
        ),
        (
            .passport,
            [
                "passport",
                "passport no",
                "date of birth",
                "place of birth",
                "nationality",
                "issuing authority"
            ]
        ),
        (
            .casLetter,
            [
                "confirmation of acceptance for studies",
                "cas statement",
                "cas number",
                "student route",
                "sponsor licence",
                "university"
            ]
        ),
        (
            .tenancyAgreement,
            [
                "tenancy agreement",
                "assured shorthold",
                "landlord",
                "tenant",
                "deposit",
                "property address"
            ]
        )
    ]

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "DocumentIntelligence"
    )
    private let processingQueue = DispatchQueue(
        label: "com.arrivaluk.document-intelligence",
        qos: .userInitiated
    )

    private init() {}

    func analyze(image: UIImage) async -> DocumentClassificationResult? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            processingQueue.async { [logger] in
                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil else {
                        if let error {
                            CrashReporter.record(error: error, context: "document_intelligence_ocr")
                        }
                        continuation.resume(returning: nil)
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let fullText = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: " ")
                        .lowercased()

                    guard !fullText.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let revision = Int(request.revision)
                    guard let classification = Self.classify(recognizedText: fullText, requestRevision: revision) else {
                        logger.info("document classify unresolved revision=\(revision, privacy: .public)")
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: classification)
                }

                request.usesLanguageCorrection = false
                request.recognitionLevel = .fast
                if #available(iOS 17.0, *) {
                    request.revision = VNRecognizeTextRequestRevision3
                    request.automaticallyDetectsLanguage = true
                } else {
                    request.revision = VNRecognizeTextRequestRevision2
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    CrashReporter.record(error: error, context: "document_intelligence_ocr_handler")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    static func classify(
        recognizedText: String,
        requestRevision: Int
    ) -> DocumentClassificationResult? {
        let fullText = recognizedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !fullText.isEmpty else { return nil }

        var bestType: SecureDocType?
        var bestScore = 0.0

        for signature in signatures {
            let hits = signature.keywords.reduce(0) { partial, keyword in
                partial + (fullText.contains(keyword) ? 1 : 0)
            }
            guard hits > 0 else { continue }
            let score = Double(hits) / Double(signature.keywords.count)
            if score > bestScore {
                bestScore = score
                bestType = signature.type
            }
        }

        guard let bestType else { return nil }
        let calibratedScore = min(max(bestScore + 0.34, 0.0), 0.99)
        return DocumentClassificationResult(
            type: bestType,
            confidence: calibratedScore,
            requestRevision: requestRevision
        )
    }
}
