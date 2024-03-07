import Foundation

struct FirewallWhitelister {
    let groupName: String
    var utils: ProcessUtilitiesProtocol

    init(groupName: String) {
        self.groupName = groupName
        self.utils = ProcessUtilities()
    }

     // Set the GID of the extension process to the whitelist group (likely "piavpn")
    // This GID is whitelisted by the firewall so we can route packets out
    // the physical interface even when the killswitch is active.
    func whitelist() -> Bool {
        log(.info, "Trying to set gid of extension (pid: \(getpid()) at \(utils.getProcessPath(pid: getpid())!) to \(groupName)")
        guard let whitelistGid = utils.getGroupIdFromName(groupName: groupName) else {
            log(.error, "Error: unable to get gid for \(groupName) group!")
            return false
        }

        // Setting either the egid or rgid successfully is a success
        guard (utils.setEffectiveGroupID(groupID: whitelistGid) || utils.setRealGroupID(groupID: whitelistGid)) else {
            log(.error, "Error: unable to set group to \(groupName) with gid: \(whitelistGid)!")
            return false
        }

        log(.info, "Should have successfully set gid of extension to \(groupName) with gid: \(whitelistGid)")
        return true
    }
}
