import Foundation

protocol Message {
}

struct HttpMessage: Message {
    let response: [UInt8]?
    let cookie: String?
    let redirect: String?
    
    init(response: [UInt8]?,
         cookie: String? = nil,
         redirect: String? = nil) {
        self.response = response
        self.cookie = cookie
        self.redirect = redirect
    }
}

struct WsMessage: Message {
    let response: AnyObject?

    init(response: AnyObject?) {
        self.response = response
    }
}

private func parseQueryString(string: String) -> [String: String] {
    return [:]
}

struct Request {
    let verb: HttpVerb
    let headers: [String: String]
    let entity: [UInt8]
    let contentType: ContentType
    let cookie: String?

    let params: [String: AnyObject]
    let json: JsonElement?
    
    init(queryParams: String?,
         verb: HttpVerb,
         headers: [String: String],
         entity: [UInt8],
         contentType: ContentType,
         extractedParams: [String: String] = [:],
         cookie: String?) {
        self.verb = verb
        self.headers = headers
        self.entity = entity
        self.contentType = contentType
        self.cookie = cookie

        self.params = extractedParams ++ {
            if let qParams = queryParams {
                return parseQueryString(qParams)
            } else {
                return [:]
            }
        } ++ {
            switch (contentType) {
            case ContentType.ApplicationFormUrlEncoded:
                return parseQueryString(String(bytes: entity,
                                               encoding: NSUTF8StringEncoding)!)
            default:
                return [:]
            }
        }

        if contentType == ContentType.ApplicationJson {
            self.json = String(bytes: entity,
                               encoding: NSUTF8StringEncoding)!.parseJson()
        } else {
            self.json = nil
        }
    }    
}

struct Input {
    let message: Message
    let contentType: ContentType
    
    /**
     Dumb datum for passing around input information.
  
     - parameter endpoint:    endpoint being targeting
     - parameter body:        input body for non-GET calls
     - parameter queryParams: query parameters in URL or in post body
     - parameter httpMethod:  http method being used (GET, POST, etc.)
     - parameter action:      action associated with this endpoint
     - parameter contentType: accepted content-types
    */
    init(endpoint: String,
         body: [UInt8],
         queryParams: String?,
         cookie: String?,
         httpVerb: HttpVerb,
         headers: [String: String],
         action: Action,
         contentType: ContentType) {
        self.contentType = contentType
        self.message = action.handler(
                           Request(
                               queryParams: queryParams,
                               verb: httpVerb,
                               headers: headers,
                               entity: body,
                               contentType: contentType,
                               extractedParams: action.actionContext.map(endpoint),
                               cookie: cookie
                               )
                       )
    }
}
