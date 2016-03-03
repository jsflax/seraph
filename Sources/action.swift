import Foundation

struct Wildcard: CustomStringConvertible {
    let actualString: String
    init(wildcard: String) {
        self.actualString = wildcard
    }

    var description: String { return actualString }
}

struct ActionContextString: CustomStringConvertible {
    let actualString: String
    private var expr: Wildcard? = nil
    var wildcards: [Wildcard] = []
    var description: String { return actualString }
}

extension Wildcard: StringLiteralConvertible {
    typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    typealias UnicodeScalarLiteralType = StringLiteralType

    init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.actualString = "\(value)"
    }

    init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.actualString = value
    }

    init(stringLiteral value: StringLiteralType) {
        self.actualString = value
    }
}

extension ActionContextString: StringInterpolationConvertible, StringLiteralConvertible {
    /// Create an instance by concatenating the elements of `strings`.
    // first, this will get called for each "segment"
    init<T>(stringInterpolationSegment expr: T) {
        print(T.Type)
        print("Processing segment: \(expr)")
        self.actualString = String(expr)
    }

    /// Create an instance containing `expr`'s `print` representation.
    init(stringInterpolationSegment expr: Wildcard) {
        print("Processing wildcard: " + String(expr))
        self.expr = expr
        self.actualString = String(expr)
    }

    init(stringInterpolation strings: ActionContextString...) {
        print("Processing final?: \(strings)")
        var iStr = ""
        for context in strings {
            if let wild = context.expr {
                print ("is wild")
                iStr += "(.+)"
                self.wildcards += [wild]
            } else {
                print ("is string")
                iStr += context.actualString
            }
        }

        self.actualString = iStr
    }

    typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    typealias UnicodeScalarLiteralType = StringLiteralType

    init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.actualString = "\(value)"
    }

    init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.actualString = value
    }

    init(stringLiteral value: StringLiteralType) {
        self.actualString = value
    }
}

class ActionContext: CustomStringConvertible {
    let actualString: String
    let endpoint: ActionContextString
    let wildcards: [Wildcard]
    let regex: Regex
    
    init(endpoint: ActionContextString) {
        self.endpoint = endpoint
        self.regex = Regex(pattern: endpoint.actualString)
        self.actualString = endpoint.actualString
        self.wildcards = endpoint.wildcards
    }

    var description: String { return actualString }

    func map(endpoint: String) -> [String: String] {
        if (wildcards.count > 0) {
            let list: [String] = regex.unapply(endpoint)
            return wildcards.map({ $0.actualString }).zip(list)
        } else {
            return [:]
        }
    }
}

struct Action {
    let handler: Request -> Message
    let contentType: ContentType
    let actionContext: ActionContext
    let verbs: [HttpVerb]
}
