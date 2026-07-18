import Darwin
import Foundation

public struct SystemAvailableMemoryProvider: AvailableMemoryProviding {
    public init() {}

    public func availableMemoryBytes() -> UInt64 {
        #if os(macOS)
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS,
              host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return ProcessInfo.processInfo.physicalMemory
        }

        let reclaimablePages = UInt64(statistics.free_count)
            + UInt64(statistics.inactive_count)
            + UInt64(statistics.speculative_count)
            + UInt64(statistics.purgeable_count)
        return reclaimablePages * UInt64(pageSize)
        #else
        return UInt64(os_proc_available_memory())
        #endif
    }
}
