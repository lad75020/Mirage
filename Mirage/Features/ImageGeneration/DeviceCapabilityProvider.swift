import Darwin
import Foundation
import Metal

public struct SystemDeviceCapabilityProvider: DeviceCapabilityProviding {
    public init() {}

    public func operatingSystemMajorVersion() -> Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    public func deviceIdentifier() -> String {
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown"
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &value, &size, nil, 0) == 0 else {
            return "unknown"
        }
        return String(cString: value)
    }

    public func supportsMetal() -> Bool {
        MTLCreateSystemDefaultDevice() != nil
    }
}
