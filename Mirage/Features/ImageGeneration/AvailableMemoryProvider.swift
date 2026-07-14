import Darwin
import Foundation

public struct SystemAvailableMemoryProvider: AvailableMemoryProviding {
    public init() {}

    public func availableMemoryBytes() -> UInt64 {
        UInt64(os_proc_available_memory())
    }
}
