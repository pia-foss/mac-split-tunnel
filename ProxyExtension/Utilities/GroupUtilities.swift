import Foundation

// Given a group name (i.e "piavpn") return the associated GID
func getGroupIdFromName(groupName: String) -> gid_t? {
    return groupName.withCString { cStringGroupName in
        var result: gid_t?
        var groupEntry = group()
        var buffer: [Int8] = Array(repeating: 0, count: 1024)
        var tempPointer: UnsafeMutablePointer<group>?

        getgrnam_r(cStringGroupName, &groupEntry, &buffer, buffer.count, &tempPointer)

        if let _ = tempPointer {
            result = groupEntry.gr_gid
        }

        return result
    }
}

func setEffectiveGroupID(groupID: gid_t) -> Bool {
    // setegid returns 0 on success, -1 on failure
    return setegid(groupID) == 0
}

func setRealGroupID(groupID: gid_t) -> Bool {
    // setgid returns 0 on success, -1 on failure
    return setgid(groupID) == 0
}
