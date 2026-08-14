import Foundation

/// Minimal read-only safetensors accessor. Memory-maps the file and copies
/// out individual float32 tensors (or row slices) on demand, so the
/// 1.5 GB `embed_tokens.weight` matrix never fully materializes in RAM.
struct SafetensorsFile: Sendable {
    struct TensorInfo: Sendable {
        let dtype: String
        let shape: [Int]
        let byteRange: Range<Int>
    }

    enum ReadError: Error, Equatable, Sendable {
        case malformedHeader
        case tensorNotFound(String)
        case unsupportedDType(String)
    }

    private let data: Data
    private let dataStart: Int
    private let tensors: [String: TensorInfo]

    init(url: URL) throws {
        data = try Data(contentsOf: url, options: .alwaysMapped)
        guard data.count > 8 else { throw ReadError.malformedHeader }
        let headerLength = data.prefix(8).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        let headerEnd = 8 + Int(headerLength)
        guard headerLength > 0, headerEnd <= data.count,
              let header = try JSONSerialization.jsonObject(
                  with: data.subdata(in: 8..<headerEnd)
              ) as? [String: Any] else {
            throw ReadError.malformedHeader
        }
        dataStart = headerEnd
        var parsed: [String: TensorInfo] = [:]
        for (key, value) in header where key != "__metadata__" {
            guard let entry = value as? [String: Any],
                  let dtype = entry["dtype"] as? String,
                  let shape = entry["shape"] as? [Int],
                  let offsets = entry["data_offsets"] as? [Int],
                  offsets.count == 2, offsets[0] <= offsets[1],
                  headerEnd + offsets[1] <= data.count else {
                throw ReadError.malformedHeader
            }
            parsed[key] = TensorInfo(dtype: dtype, shape: shape, byteRange: offsets[0]..<offsets[1])
        }
        tensors = parsed
    }

    func shape(of name: String) throws -> [Int] {
        guard let info = tensors[name] else { throw ReadError.tensorNotFound(name) }
        return info.shape
    }

    /// Copies a full float32 tensor out of the mapped file.
    func floatTensor(_ name: String) throws -> [Float] {
        guard let info = tensors[name] else { throw ReadError.tensorNotFound(name) }
        guard info.dtype == "F32" else { throw ReadError.unsupportedDType(info.dtype) }
        return copyFloats(byteRange: info.byteRange)
    }

    /// Copies `rowCount` contiguous rows starting at `row` from a 2-D float32
    /// tensor without touching the rest of the mapping.
    func floatRows(_ name: String, row: Int, rowCount: Int = 1) throws -> [Float] {
        guard let info = tensors[name] else { throw ReadError.tensorNotFound(name) }
        guard info.dtype == "F32" else { throw ReadError.unsupportedDType(info.dtype) }
        guard info.shape.count == 2, row >= 0, rowCount >= 0, row + rowCount <= info.shape[0] else {
            throw ReadError.malformedHeader
        }
        let rowBytes = info.shape[1] * MemoryLayout<Float>.size
        let start = info.byteRange.lowerBound + row * rowBytes
        return copyFloats(byteRange: start..<(start + rowCount * rowBytes))
    }

    private func copyFloats(byteRange: Range<Int>) -> [Float] {
        let start = dataStart + byteRange.lowerBound
        let end = dataStart + byteRange.upperBound
        let count = (end - start) / MemoryLayout<Float>.size
        var values = [Float](repeating: 0, count: count)
        _ = values.withUnsafeMutableBytes { destination in
            data.copyBytes(to: destination, from: start..<end)
        }
        return values
    }
}
