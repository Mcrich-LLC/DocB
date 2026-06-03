import Foundation

/// Centralizes device-capability thresholds for extra Apple symbol search prewarming.
public enum SearchPrewarmPolicy {
    /// Number of bytes in one gibibyte.
    public static let gibibyte: UInt64 = 1_024 * 1_024 * 1_024

    /// Minimum physical memory required to run extra Apple symbol search prewarming on macOS.
    public static let macOSMinimumPhysicalMemory: UInt64 = 12 * gibibyte

    /// Minimum physical memory required to run extra Apple symbol search prewarming on iOS and iPadOS.
    public static let iOSMinimumPhysicalMemory: UInt64 = 6 * gibibyte

    /// Minimum physical memory required to run extra Apple symbol search prewarming on visionOS.
    public static let visionOSMinimumPhysicalMemory: UInt64 = 8 * gibibyte

    /// Minimum physical memory required for extra Apple symbol search prewarming on the current platform.
    public static var currentPlatformMinimumPhysicalMemory: UInt64? {
        #if os(macOS)
        macOSMinimumPhysicalMemory
        #elseif os(iOS)
        iOSMinimumPhysicalMemory
        #elseif os(visionOS)
        visionOSMinimumPhysicalMemory
        #else
        nil
        #endif
    }

    /// Returns whether the current device should perform extra Apple symbol search prewarming.
    ///
    /// - Parameter physicalMemory: Physical memory in bytes. Defaults to the current device memory.
    /// - Returns: `true` when the current platform has enough memory for extra Apple symbol search prewarming.
    public static func canPrewarmAppleSymbolSearchInBackground(
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Bool {
        guard let currentPlatformMinimumPhysicalMemory else {
            return false
        }

        return physicalMemory >= currentPlatformMinimumPhysicalMemory
    }
}
