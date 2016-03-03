//
// Created by Jason Flax on 2/29/16.
//

import Foundation

/**
 * Internal logger.
 */ //TODO: Connect to offline store for ... logging (duh)
class log {
    private static let BLUE = "\u{001B}[94m"
    private static let GREEN = "\u{001B}[92m"
    private static let YELLOW = "\u{001B}[93m"
    private static let RED = "\u{001B}[91m"
    private static let CLEAR = "\u{001B}[0m"
    private static let LIGHT_PURPLE = "\u{001B}[35m"
    private static let CYAN = "\u{001B}[36m"

    static let INFO = 0
    private static let _info = {
        (msg: String, level: String) in log.printer(msg,
                                                    level: level,
                                                    color: BLUE)
    }
    
    static let ERROR = 1
    private static let _error = {
        (msg: String, level: String) in log.printer(msg,
                                                    level: level,
                                                    color: RED)
    }
    
    static let WARN = 2
    private static let _warn = {
        (msg: String, level: String) in log.printer(msg,
                                                    level: level,
                                                    color: YELLOW)
    }
    
    static let TRACE = 3
    private static let _trace = {
        (msg: String, level: String) in log.printer(msg,
                                                    level: level,
                                                    color: GREEN)
    }
    
    static let DEBUG = 4
    private static let _debug = {
        (msg: String, level: String) in log.printer(msg,
                                                    level: level,
                                                    color: LIGHT_PURPLE)
    }
    
    static let VERBOSE = 5
    private static let _verbose = {
        (msg: String, level: String) in log.printer(msg,
                                                    level: level,
                                                    color: CYAN)
    }
    
    static var on: Bool = true

    private static let functionSet: [Int: (String, String) -> Void] = [
                INFO: _info,
                ERROR: _error,
                WARN: _warn,
                TRACE: _trace,
                DEBUG: _debug,
                VERBOSE: _verbose
    ]

    private static var filters = functionSet

    static func setLogLevels(levels: Int...) {
        let empty = { (msg: String, lvl: String) in
        }

        let range = 0 ... 5
        let (filter, filterNot) = range.partition({levels.contains($0)})

        filter.foreach({filters[$0] = functionSet[$0]})
        filterNot.foreach({filters[$0] = empty})
    }

    private static func printer(msg: String, level: String, color: String) {
        if (on) {
            print(
                "\(color)[\(level)] \(msg)\(CLEAR)"
            )
        }
    }

    static func info(msg: String) {
        filters[INFO]!(msg, "info")
    }
    static func error(msg: String) {
        filters[ERROR]!(msg, "error")
    }
    static func warn(msg: String) {
        filters[WARN]!(msg, "warn")
    }
    static func trace(msg: String) {
        filters[TRACE]!(msg, "trace")
    }
    static func debug(msg: String) {
        filters[DEBUG]!(msg, "debug")
    }
    static func verbose(msg: String) {
        filters[VERBOSE]!(msg, "verbose")
    }

    static func i(msg: String) {
        info(msg)
    }
    static func e(msg: String) {
        error(msg)
    }
    static func w(msg: String) {
        warn(msg)
    }
    static func t(msg: String) {
        trace(msg)
    }
    static func d(msg: String) {
        debug(msg)
    }
    static func v(msg: String) {
        verbose(msg)
    }
}
