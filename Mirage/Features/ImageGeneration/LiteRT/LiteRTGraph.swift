#if os(iOS)
import Foundation
import LiteRTRuntime

/// Errors thrown by the on-device LiteRT graph runtime.
enum LiteRTError: Error, Equatable, Sendable {
    case modelLoadFailed(String)
    case interpreterCreationFailed(String)
    case signatureMissing(String)
    case tensorMissing(String)
    case shapeMismatch(String, expected: Int, actual: Int)
    case invokeFailed(String)
}

/// One `.tflite` graph opened through the TensorFlow Lite C API with a
/// `serving_default` signature runner and the XNNPACK CPU delegate.
///
/// Not thread-safe; owned and serialized by the pipeline actor.
final class LiteRTGraph {
    let name: String
    private let model: OpaquePointer
    private let options: OpaquePointer
    private let interpreter: OpaquePointer
    private let runner: OpaquePointer
    private let delegateHandle: UnsafeMutablePointer<TfLiteDelegate>?
    private let inputNames: [String]
    private let outputNames: [String]

    init(url: URL, threads: Int32) throws {
        name = url.lastPathComponent
        guard let model = TfLiteModelCreateFromFile(url.path) else {
            throw LiteRTError.modelLoadFailed(url.lastPathComponent)
        }
        let options = TfLiteInterpreterOptionsCreate()!
        TfLiteInterpreterOptionsSetNumThreads(options, threads)
        var xnnOptions = TfLiteXNNPackDelegateOptionsDefault()
        xnnOptions.num_threads = threads
        let delegateHandle = TfLiteXNNPackDelegateCreate(&xnnOptions)
        if let delegateHandle {
            TfLiteInterpreterOptionsAddDelegate(options, delegateHandle)
        }
        guard let interpreter = TfLiteInterpreterCreate(model, options) else {
            TfLiteInterpreterOptionsDelete(options)
            if let delegateHandle { TfLiteXNNPackDelegateDelete(delegateHandle) }
            TfLiteModelDelete(model)
            throw LiteRTError.interpreterCreationFailed(url.lastPathComponent)
        }
        guard let runner = TfLiteInterpreterGetSignatureRunner(interpreter, "serving_default"),
              TfLiteSignatureRunnerAllocateTensors(runner) == kTfLiteOk else {
            TfLiteInterpreterDelete(interpreter)
            TfLiteInterpreterOptionsDelete(options)
            if let delegateHandle { TfLiteXNNPackDelegateDelete(delegateHandle) }
            TfLiteModelDelete(model)
            throw LiteRTError.signatureMissing(url.lastPathComponent)
        }
        self.model = model
        self.options = options
        self.interpreter = interpreter
        self.runner = runner
        self.delegateHandle = delegateHandle
        inputNames = (0..<TfLiteSignatureRunnerGetInputCount(runner)).compactMap {
            TfLiteSignatureRunnerGetInputName(runner, Int32($0)).map { String(cString: $0) }
        }.sorted()
        outputNames = (0..<TfLiteSignatureRunnerGetOutputCount(runner)).compactMap {
            TfLiteSignatureRunnerGetOutputName(runner, Int32($0)).map { String(cString: $0) }
        }.sorted()
    }

    deinit {
        TfLiteSignatureRunnerDelete(runner)
        TfLiteInterpreterDelete(interpreter)
        TfLiteInterpreterOptionsDelete(options)
        if let delegateHandle { TfLiteXNNPackDelegateDelete(delegateHandle) }
        TfLiteModelDelete(model)
    }

    /// Runs the signature with positional float32 inputs (`args_0`, `args_1`, ...)
    /// and returns the single float32 output (`output_0`).
    func run(_ inputs: [[Float]]) throws -> [Float] {
        guard inputs.count == inputNames.count else {
            throw LiteRTError.shapeMismatch(name, expected: inputNames.count, actual: inputs.count)
        }
        for (index, values) in inputs.enumerated() {
            let inputName = "args_\(index)"
            guard inputNames.contains(inputName),
                  let tensor = TfLiteSignatureRunnerGetInputTensor(runner, inputName) else {
                throw LiteRTError.tensorMissing("\(name):\(inputName)")
            }
            let expected = TfLiteTensorByteSize(tensor) / MemoryLayout<Float>.size
            guard expected == values.count else {
                throw LiteRTError.shapeMismatch("\(name):\(inputName)", expected: expected, actual: values.count)
            }
            let status = values.withUnsafeBufferPointer { buffer in
                TfLiteTensorCopyFromBuffer(tensor, buffer.baseAddress, buffer.count * MemoryLayout<Float>.size)
            }
            guard status == kTfLiteOk else { throw LiteRTError.invokeFailed("\(name):\(inputName)") }
        }
        guard TfLiteSignatureRunnerInvoke(runner) == kTfLiteOk else {
            throw LiteRTError.invokeFailed(name)
        }
        guard let outputName = outputNames.first,
              let output = TfLiteSignatureRunnerGetOutputTensor(runner, outputName) else {
            throw LiteRTError.tensorMissing("\(name):output_0")
        }
        let count = TfLiteTensorByteSize(output) / MemoryLayout<Float>.size
        var result = [Float](repeating: 0, count: count)
        let status = result.withUnsafeMutableBufferPointer { buffer in
            TfLiteTensorCopyToBuffer(output, buffer.baseAddress, buffer.count * MemoryLayout<Float>.size)
        }
        guard status == kTfLiteOk else { throw LiteRTError.invokeFailed("\(name):output_0") }
        return result
    }
}

#endif
