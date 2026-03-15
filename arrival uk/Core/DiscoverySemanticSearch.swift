import Foundation
import NaturalLanguage

struct DiscoverySemanticCandidate: Hashable {
    let id: String
    let title: String
    let subtitle: String
}

enum DiscoverySemanticSearch {
    static func rank(
        candidates: [DiscoverySemanticCandidate],
        query: String
    ) -> [String] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return candidates.map(\.id)
        }

        let queryTokens = tokenize(normalizedQuery)
        guard !queryTokens.isEmpty else {
            return candidates.map(\.id)
        }

        let embedding = NLEmbedding.wordEmbedding(for: .english)

        let scored = candidates.compactMap { candidate -> (String, Double)? in
            let text = normalize("\(candidate.title) \(candidate.subtitle)")
            let candidateTokens = tokenize(text)
            guard !candidateTokens.isEmpty else { return nil }

            let overlap = keywordOverlapScore(queryTokens: queryTokens, candidateTokens: candidateTokens)
            let embeddingScore = embeddingScore(
                queryTokens: queryTokens,
                candidateTokens: candidateTokens,
                embedding: embedding
            )
            let containsBoost = text.contains(normalizedQuery) ? 0.16 : 0.0
            let score = max(overlap * 0.85, embeddingScore) + containsBoost

            guard score > 0.12 else { return nil }
            return (candidate.id, score)
        }

        let sortedIDs = scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0 < rhs.0
            }
            .map(\.0)

        return sortedIDs
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if token.count >= 2 {
                tokens.append(token)
            }
            return true
        }
        return tokens
    }

    private static func keywordOverlapScore(queryTokens: [String], candidateTokens: [String]) -> Double {
        let querySet = Set(queryTokens)
        let candidateSet = Set(candidateTokens)
        let overlap = querySet.intersection(candidateSet).count
        guard !querySet.isEmpty else { return 0 }
        return Double(overlap) / Double(querySet.count)
    }

    private static func embeddingScore(
        queryTokens: [String],
        candidateTokens: [String],
        embedding: NLEmbedding?
    ) -> Double {
        guard let embedding else { return 0 }
        guard !queryTokens.isEmpty, !candidateTokens.isEmpty else { return 0 }

        var total = 0.0
        var used = 0

        for queryToken in queryTokens {
            guard embedding.contains(queryToken) else { continue }
            var bestTokenScore = 0.0
            for candidateToken in candidateTokens where embedding.contains(candidateToken) {
                let distance = embedding.distance(between: queryToken, and: candidateToken)
                let similarity = max(0, 1 - distance)
                bestTokenScore = max(bestTokenScore, similarity)
            }
            if bestTokenScore > 0 {
                used += 1
                total += bestTokenScore
            }
        }

        guard used > 0 else { return 0 }
        return total / Double(used)
    }
}
