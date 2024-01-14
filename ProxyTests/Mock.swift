//
//  Mock.swift
//  SplitTunnelProxyTests
//
//  Created by John Mair on 12/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

// AnyObject constrains the protocol to class types
// This is necessary as record() is a mutating function
// which struct types do not (easily) allow
protocol Mock: AnyObject {
    var methodsCalled: Set<String> { get set }
    var argumentsGiven: Dictionary<String, [Any]> { get set }
}

// Default implementation
extension Mock {
    // Indicates whether a function was called
    func didCall(_ name: String) -> Bool {
        methodsCalled.contains(name)
    }
    
    // Determines if an argument at a specified index matches a given value.
    //
    // This function compares an argument, identified by its position in the
    // arguments list, with a provided value. The comparison returns `true` if
    // they are equal, and `false` otherwise.
    //
    // Due to Swift's type inference system, the function requires the value to
    // be passed in as a parameter of type `T`. This approach is necessary because
    // Swift does not support explicitly specifying types for generics during
    // instantiation, unlike C++. Therefore, we cannot directly return the
    // argument for external comparison or use syntax like
    // `didCallWithArgAt<UInt64>("createTCP", index: 1) == 1`.
    // Instead we use it like so:
    //
    // didCallWithArgAt("createTCP", index: 1, value: 55)
    //
    // This call compares the argument at the given positional index 1 (the second element)
    // in the 'createTCP' function call with the value '55'. It returns true if the
    // argument at this index matches '55', and false otherwise.
    //
    // The 'index' parameter specifies the position in the argument list, and 'value' is
    // the value to compare against the argument at that position.
    func didCallWithArgAt<T: Equatable>(_ name: String, index: Int, value: T) -> Bool {
        guard let argArray = argumentsGiven[name], index < argArray.count else {
            return false
        }

        // Attempt to cast the element to type T
         if let element = argArray[index] as? T {
             // Compare the casted element to the value parameter
             return element == value
         } else {
             // The cast failed or the types do not match
             return false
         }
    }

    // Records the calling of a function
    func record(args: [Any], name: String=#function) {
        let elidedName = functionNameOnly(fullName: name)
        argumentsGiven[elidedName] = args
        methodsCalled.insert(elidedName)
    }

    // The #function directive returns the full name including the parameter names
    // so we need to strip out the parameters and return just the name
    private func functionNameOnly(fullName: String) -> String {
        // Find the opening parenthesis "(" to get the bare function name
        if let index = fullName.firstIndex(of: "(") {
            return String(fullName[..<index])
        }
        // If no "(" found, return the original function name
        return fullName
    }
}
