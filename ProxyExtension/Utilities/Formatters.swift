import Foundation

// Given a byteCount, format the output nicely in a human-friendly way
// including units such as KB, MB, GB, etc
func formatByteCount(_ byteCount: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB] // Options are .useBytes, .useKB, .useMB, .useGB, etc.
    formatter.countStyle = .file  // Options are .file (1024 bytes = 1KB) or .memory (1000 bytes = 1KB)
    formatter.includesUnit = true // Whether to include the unit string (KB, MB, etc.)
    formatter.isAdaptive = true

    // Converting from UInt64 to Int64 - not ideal but not a problem in practice
    // as Int64 can represent values up to 9 exabytes
    return formatter.string(fromByteCount: Int64(byteCount))
}
