import Foundation

extension String {
    func trim() -> String {
        return stringByTrimmingCharactersInSet(
        NSCharacterSet.whitespaceAndNewlineCharacterSet()
        )
    }

    func r() -> Regex {
        return Regex(pattern: self)
    }

    subscript(r: Range<Int>) -> String {
        return substringWithRange(
        Range(start: startIndex.advancedBy(r.startIndex),
                end: startIndex.advancedBy(r.endIndex)))
    }

    func base64() -> String {
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)

        return data!.base64EncodedStringWithOptions(
        NSDataBase64EncodingOptions(rawValue: 0)
        )
    }
}

func base64(bytes: [UInt8]) -> String {
    return NSData(bytes: bytes, length: bytes.count).base64EncodedStringWithOptions(
    NSDataBase64EncodingOptions(rawValue: 0)
    )
}

extension Range {
    func partition(part: (Element) -> Bool) -> (Array<Element>, Array<Element>) {
        var l = Array<Element>()
        var r = Array<Element>()

        for item in self {
            if (part(item)) {
                l += [item]
            } else {
                r += [item]
            }
        }

        return (l, r)
    }
}

extension Array {
    func foreach(iteratee: (Element) -> Void) -> Void {
        for item in self {
            iteratee(item)
        }
    }

    func partition(part: (Element) -> Bool) -> (Array<Element>, Array<Element>) {
        var l = Array<Element>()
        var r = Array<Element>()

        for item in self {
            if (part(item)) {
                l += [item]
            } else {
                r += [item]
            }
        }

        return (l, r)
    }

    func mkString() -> String {
        var out = ""
        for item in self {
            out += String(item)
        }
        return out
    }

    func collectFirst(collector: (Element) -> Bool) -> Element? {
        for item in self {
            if collector(item) {
                return item
            }
        }

        return nil
    }

    func forall(collector: (Element) -> Bool) -> Bool {
        for item in self {
            if !collector(item) {
                return false
            }
        }

        return true
    }

    func find(closure: (Element) -> Bool) -> Element? {
        for item in self {
            if closure(item) {
                return item
            }
        }

        return nil
    }

    func map<T>(closure: (Element) -> T?) -> [T] {
        var tArray: [T] = []
        for item in self {
            if let newItem = closure(item) {
                tArray += [newItem]
            }
        }
        return tArray
    }
}

extension Array where Element: Hashable {
    func zip<T>(array: [T]) -> [Element:T] {
        var map: [Element:T] = [:]

        log.e("count: \(array.count)")
        for i in 0 ... self.count {
            log.e("iter")
            if i < array.count {
                map[self[i]] = array[i]
            }
        }

        return map
    }
}

extension NSDictionary {
    func toJson() -> String {
        do {
            let stringData =
            try NSJSONSerialization.dataWithJSONObject(
            self,
                    options: NSJSONWritingOptions.PrettyPrinted
            )
            if let string = String(data: stringData,
                    encoding: NSUTF8StringEncoding) {
                return string
            }
        } catch _ {
            log.e("Error parsing JSON")
        }

        return ""
    }
}

func JSON(dict: [String:NSObject]) -> String {
    do {
        let stringData =
        try NSJSONSerialization.dataWithJSONObject(
        dict,
                options: NSJSONWritingOptions.PrettyPrinted
        )
        if let string = String(data: stringData,
                encoding: NSUTF8StringEncoding) {
            return string
        }
    } catch _ {
        log.e("Error parsing JSON")
    }

    return ""
}

func +=<K, V>(inout left: Dictionary<K, V>, right: Dictionary<K, V>) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

func +=<K, V>(inout left: Dictionary<K, V>, right: () -> Dictionary<K, V>) {
    let r = right()
    for (k, v) in r {
        left.updateValue(v, forKey: k)
    }
}

infix operator ++ { associativity left precedence 150 }
prefix operator + {}

prefix func +(str: ActionContextString) -> ActionContext {
    return ActionContext(endpoint: str)
}

prefix operator ~ {}

prefix func ~(str: String) -> Wildcard {
    return Wildcard(wildcard: str)
}

func ++<K, V>(left: Dictionary<K, V>,
              right: () -> Dictionary<K, V>) -> Dictionary<K, V> {
    var l = left
    let r = right()
    for (k, v) in r {
        l[k] = v
    }

    return l
}

func async(background: (() -> Void)?) {
    print("dispatching")
    dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
        print("in async")
        if (background != nil) {
            print("running bag")
            background!()
        }
    }
}

func wait() {
    while true {
        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1));
        NSThread.sleepForTimeInterval(0.1)
    }
}

struct Regex {
    let pattern: String
    var options: NSRegularExpressionOptions = []

    private var matcher: NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: self.pattern,
                    options: self.options)
        } catch _ {
            print("error")
        }

        return nil
    }

    init(pattern: String, options: NSRegularExpressionOptions = []) {
        self.pattern = pattern
        self.options = options
    }

    func matches(string: String, options: NSMatchingOptions = []) -> Bool {
        let m = self.matcher!.numberOfMatchesInString(
        string,
                options: options,
                range: NSMakeRange(0, string.utf16.count))
        return m != 0
    }

    func unapply(string: String) -> [String] {
        return self.matcher!.matchesInString(string,
                options: [],
                range: NSMakeRange(0, string.utf16.count)
        ).map({
            match in
            if (match.numberOfRanges > 0) {
                let matchRange = match.rangeAtIndex(1)
                return (string as NSString).substringWithRange(matchRange)
            } else {
                return nil
            }
        })
    }
}

func fromBytes(bytes: [UInt8]) -> String? {
    return String(bytes: bytes, encoding: NSUTF8StringEncoding)
}

extension Regex: StringLiteralConvertible {
    typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    typealias UnicodeScalarLiteralType = StringLiteralType

    init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.pattern = "\(value)"
    }

    init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.pattern = value
    }

    init(stringLiteral value: StringLiteralType) {
        self.pattern = value
    }
}
