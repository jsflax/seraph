import Foundation

extension String {
    func parseJson() -> JsonElement? {
        let data = self.dataUsingEncoding(NSUTF8StringEncoding,
                                          allowLossyConversion: false)

        if let jsonData = data {
            // Will return an object or nil if JSON decoding fails
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(jsonData,
                                                                      options: NSJSONReadingOptions.MutableContainers)
                return JsonElement(json: json)
            } catch let jsError as NSError {
                log.error("\(jsError)")
            }

            return nil
        } else {
            // Lossless conversion of the string was not possible
            return nil
        }
    }
}

class JsonElement {
    let json: AnyObject?

    private init(json: AnyObject?) {
        self.json = json
    }

    func convertTo<T>(type: T.Type) -> T? {
        guard let retVal = self.json as! T? else {
            return nil
        }

        return retVal
    }
}
