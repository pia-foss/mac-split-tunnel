
import Foundation

@testable import SplitTunnelProxyExtensionFramework
final class MockProcessUtilities: ProcessUtilitiesProtocol, Mock {
    // Required by Mock
    var methodsCalled: Set<String> = []
    var argumentsGiven: Dictionary<String, [Any]> = [:]

    func getGroupIdFromName(groupName: String) -> gid_t? {
        record()

        return 123
    }

    func setEffectiveGroupID(groupID: gid_t) -> Bool {
        record()

        return true
    }
    func setRealGroupID(groupID: gid_t) -> Bool {
        record()

        return true
    }
    func getProcessPath(pid: pid_t) -> String? {
        record()

        return "/foo/bar"
    }
}
