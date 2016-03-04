//
// Created by Jason Flax on 3/2/16.
//

import Foundation


class HttpProtocolManager: IOManager {
    // Yield the output that will be written to the socket.
    // -parameter message: messaged generated from handled input
    // -parameter contentType: rfc content type to be declared over the wire 
    // -parameter closed: whether or not to keep the connection alive
    //
    // -return byte array to be written to socket
    //
    // TODO: support all rfc status codes
    private func yieldOutput(message: HttpMessage,
                             contentType: ContentType,
                             closed: Bool = true) -> [UInt8] {
        var out: [UInt8] = []
        // if response is not nil, write a standard http 1.1 message
        // else, write a standard bad request
        if let response = message.response {
            // if redirect, use 302
            // else, 200 OK
            if let redirect = message.redirect {
                out += "HTTP/1.1 302 Found\r\n".utf8
                out += "Location: \(redirect)\r\n".utf8
            } else {
                out += "HTTP/1.1 200 OK\r\n".utf8
            }

            // if we have a cookie, set it
            if let cookie = message.cookie {
                out += "Set-Cookie: \(cookie)\r\n".utf8
            }

            // set content-type and length as per http 1.1
            out += "Server: WebServer\r\n".utf8
            out += "Content-Type: \(contentType)\r\n".utf8
            out += "Content-Length: \(response.count)\r\n".utf8

            // set if connection should remain alive or closed
            if closed {
                out += "Connection: close\r\n".utf8
            } else {
                out += "Connection: Keep-Alive\r\n".utf8
            }

            // carry, return, and write response
            out += "\r\n".utf8
            out += response
            out += "\r\n".utf8
        } else {
            out += "HTTP/1.1 400 Bad request\r\n".utf8
            out += "Server: WebServer\r\n".utf8
            out += "Connection: close\r\n".utf8
            out += "\r\n".utf8
        }

        return out
    }

    private func readInput(input: String) -> Input? {
        // divide string input by new line character
        // and remove all extraneous chars
        var lines: [String] = input.componentsSeparatedByString("\n").map {
            $0.stringByTrimmingCharactersInSet(
            NSCharacterSet.init(charactersInString: "\n \r \0")
            )
        }

        log.v("\(lines)")

        // dequeue the first line
        var line = lines.removeFirst()

        // parse the hit endpoint. as per rfc2616 standards,
        // this should be separated by a space
        var endpoint = line.characters.split {
            $0 == " "
        }.map {
            String($0)
        }[1].trim()

        // parse the http verb associated with this call
        let httpVerb = HttpVerb.values.collectFirst {
            line.hasPrefix("\($0)")
        }

        // if the verb is not supported, short circuit the
        // function
        if httpVerb == nil {
            log.e(
            String(line.characters.split {
                $0 == " "
            }.map { String($0) })
            )

            return nil
        }

        var contentLength = 0
        var contentType = ContentType.NoneType
        var cookie: String? = nil
        var headers: [String:String] = [:]

        // iterate through the remaining lines up to and excluding
        // the body
        while (line != "") {
            // if not GET, there is no body content, ergo,
            // do not parse
            if httpVerb! != HttpVerb.GET {
                let contentHeader = "content-length: "
                let contentTypeHeader = "content-type: "
                let cookieHeader = "cookie: "

                if line.lowercaseString.hasPrefix(contentHeader) {
                    contentLength = Int(
                    line[contentHeader.characters.count ..<
                           line.characters.count]
                    )!
                } else if line.lowercaseString.hasPrefix(contentTypeHeader) {
                    let types = line[contentTypeHeader.characters.count ..<
                                       line.characters.count]
                    let typeOpt = ContentType.values.collectFirst { type in
                        return types == "\(type.rawValue)"
                    }
                    if let type = typeOpt {
                        contentType = type
                    } else {
                        return nil
                    }
                } else if line.lowercaseString.hasPrefix(cookieHeader) {
                    cookie = line[cookieHeader.characters.count ..<
                                    line.characters.count]
                } else {
                    let header = line.characters.split {
                        $0 == ":"
                    }.map {
                        String($0)
                    }

                    // TODO: the split is removing the colons
                    if header.forall({ !$0.isEmpty }) {
                        headers[header[0]] =
                                Array(header[1 ..< header.count]).mkString()
                    }
                }
            }

            // dequeue next line
            line = lines.removeFirst()
        }

        log.v("Headers: \(headers)")
        
        var queryParameters: String? = nil
        var body: [UInt8] = []

        // determine if the endpoint contains parameters
        // at the rear end
        if endpoint.characters.contains("?") {
            // reset the endpoint to be in it's raw state (without params)
            // set the query params variable
            let epSplit = endpoint.characters.split {
                $0 == "?"
            }.map {
                String($0)
            }

            endpoint = epSplit[0]
            queryParameters = epSplit[1]
        }

        log.e("\(endpoint)")

        // use regex to determine if the hit endpoint matches
        // an endpoint that we have mapped on the server
        let action = HttpController.actionRegistrants.collectFirst {
            String($0.actionContext).r().matches(endpoint)
        }

        // if yes, generate an input datum for consumption
        if let actor = action {
            log.v("\(actor.actionContext.endpoint)")

            // if not get, fetch the remainder of the body
            if httpVerb != HttpVerb.GET {
                body = [UInt8](lines.mkString().utf8)
            }

            // check if this endpoint supports the http verb that was used
            // if yes, handle the input
            // else, short circuit
            if let verb = actor.verbs.find({httpVerb! == $0}) {
                return Input(endpoint: endpoint,
                             body: body,
                             queryParams: queryParameters,
                             cookie: cookie,
                             httpVerb: verb,
                             headers: headers,
                             action: actor,
                             contentType: contentType)
            } else {
                log.e("could not find verb")
                return nil
            }
        } else {
            log.e("action was nil")
            return nil
        }
    }

    internal override func ioLoop(socket: Socket) {
        log.trace("Reading Input")

        // close socket after this block is complete
        // no matter what happens
        defer {
            socket.close()
        }

        // read input wholly from the newly accepted socket
        let inputStream = socket.read()

        // if not nil, parse the input
        if let buffer = inputStream {
            let inputOpt = readInput(
                    NSString(data: NSData(bytes: buffer,
                                          length: buffer.count),
                             encoding: NSUTF8StringEncoding) as! String)

            // if not nil, fetch the handled input
            // and yield output to the client
            if let input = inputOpt {
                let output = yieldOutput(input.message as! HttpMessage,
                                         contentType: input.contentType)
                socket.write(output)
            }
        }
    }
}
