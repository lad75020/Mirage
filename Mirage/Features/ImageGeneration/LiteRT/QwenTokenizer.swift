import Foundation

/// Self-contained Qwen2 byte-level BPE tokenizer.
///
/// Reads `tokenizer.json` (vocab + merges + added special tokens) and applies
/// the fixed Z-Image chat template verified against the reference pipeline:
/// `<|im_start|>user\n{prompt}<|im_end|>\n<|im_start|>assistant\n`.
struct QwenTokenizer: Sendable {
    enum TokenizerError: Error, Equatable, Sendable {
        case malformedTokenizerFile
    }

    static let padTokenID = 151_643 // <|endoftext|>

    private let vocab: [String: Int]
    private let mergeRanks: [String: Int]
    private let specialTokens: [String: Int]

    /// GPT-2 style byte-to-printable-unicode table used by byte-level BPE.
    private static let byteEncoder: [UInt8: Character] = {
        var byteValues: [Int] = []
        byteValues.append(contentsOf: 33...126)
        byteValues.append(contentsOf: 161...172)
        byteValues.append(contentsOf: 174...255)
        var mapping: [UInt8: Character] = [:]
        var extra = 0
        for byte in 0...255 {
            if byteValues.contains(byte) {
                mapping[UInt8(byte)] = Character(UnicodeScalar(byte)!)
            } else {
                mapping[UInt8(byte)] = Character(UnicodeScalar(256 + extra)!)
                extra += 1
            }
        }
        return mapping
    }()

    /// Qwen2 pre-tokenization pattern (from tokenizer.json `pretokenizer`).
    private static let pretokenPattern =
        #"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"#

    init(tokenizerJSONURL: URL) throws {
        let data = try Data(contentsOf: tokenizerJSONURL, options: .alwaysMapped)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = root["model"] as? [String: Any],
              let vocabRaw = model["vocab"] as? [String: Int],
              let mergesRaw = model["merges"] as? [Any] else {
            throw TokenizerError.malformedTokenizerFile
        }
        vocab = vocabRaw
        var ranks: [String: Int] = [:]
        ranks.reserveCapacity(mergesRaw.count)
        for (rank, merge) in mergesRaw.enumerated() {
            if let pair = merge as? [String], pair.count == 2 {
                ranks["\(pair[0]) \(pair[1])"] = rank
            } else if let joined = merge as? String {
                ranks[joined] = rank
            }
        }
        mergeRanks = ranks
        var special: [String: Int] = [:]
        for token in (root["added_tokens"] as? [[String: Any]]) ?? [] {
            if let content = token["content"] as? String, let id = token["id"] as? Int {
                special[content] = id
            }
        }
        specialTokens = special
    }

    /// Applies the Z-Image chat template and encodes, padded/truncated to `length`.
    /// Returns (ids, validCount).
    func encodeForZImage(prompt: String, length: Int) -> (ids: [Int], validCount: Int) {
        var ids: [Int] = []
        ids.append(specialTokens["<|im_start|>"] ?? 151_644)
        ids.append(contentsOf: encodeText("user\n"))
        ids.append(contentsOf: encodeText(prompt))
        ids.append(specialTokens["<|im_end|>"] ?? 151_645)
        ids.append(contentsOf: encodeText("\n"))
        ids.append(specialTokens["<|im_start|>"] ?? 151_644)
        ids.append(contentsOf: encodeText("assistant\n"))
        if ids.count > length {
            ids = Array(ids.prefix(length))
        }
        let valid = ids.count
        while ids.count < length {
            ids.append(Self.padTokenID)
        }
        return (ids, valid)
    }

    /// Byte-level BPE encoding of plain text (no special-token handling).
    func encodeText(_ text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: Self.pretokenPattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var ids: [Int] = []
        for match in matches {
            let piece = nsText.substring(with: match.range)
            let mapped = String(piece.utf8.map { Self.byteEncoder[$0]! })
            for token in bpe(mapped) {
                if let id = vocab[token] {
                    ids.append(id)
                }
            }
        }
        return ids
    }

    private func bpe(_ token: String) -> [String] {
        var word = token.map { String($0) }
        guard word.count > 1 else { return word }
        while true {
            var bestRank = Int.max
            var bestIndex = -1
            for i in 0..<(word.count - 1) {
                if let rank = mergeRanks["\(word[i]) \(word[i + 1])"], rank < bestRank {
                    bestRank = rank
                    bestIndex = i
                }
            }
            guard bestIndex >= 0 else { break }
            word.replaceSubrange(bestIndex...(bestIndex + 1), with: [word[bestIndex] + word[bestIndex + 1]])
            if word.count == 1 { break }
        }
        return word
    }
}
