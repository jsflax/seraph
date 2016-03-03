//
// Created by Jason Flax on 3/2/16.
//

import Foundation


class HttpProtocolManager: IOManager {
    private func yieldOutput(message: HttpMessage,
                             contentType: ContentType,
                             closed: Bool = true) -> [UInt8] {
        var out = [UInt8]()
        if let response = message.response {
            if let redirect = message.redirect {
                out += "HTTP/1.1 302 Found\r\n".utf8
                out += "Location: \(redirect)\r\n".utf8
            } else {
                out += "HTTP/1.1 200 OK\r\n".utf8
            }

            if let cookie = message.cookie {
                out += "Set-Cookie: \(cookie)\r\n".utf8
            }

            out += "Server: WebServer\r\n".utf8
            out += "Content-Type: \(contentType)\r\n".utf8
            out += "Content-Length: \(response.count)\r\n".utf8

            if closed {
                out += "Connection: close\r\n".utf8
            } else {
                out += "Connection: Keep-Alive\r\n".utf8
            }

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
        var lines: [String] = input.componentsSeparatedByString("\n").map {
            $0.stringByTrimmingCharactersInSet(
            NSCharacterSet.init(charactersInString: "\n \r \0")
            )
        }

        log.v("\(lines)")

        var line = lines.removeFirst()

        var endpoint = line.characters.split {
            $0 == " "
        }.map {
            String($0)
        }[1].trim()

        let httpVerb = HttpVerb.values.collectFirst {
            line.hasPrefix("\($0)")
        }

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

        while (line != "") {

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

            line = lines.removeFirst()
        }

        log.v("Headers: \(headers)")
        var queryParameters: String? = nil
        var body: [UInt8] = []

        if endpoint.characters.contains("?") {
            let epSplit = endpoint.characters.split {
                $0 == "?"
            }.map {
                String($0)
            }

            endpoint = epSplit[0]
            queryParameters = epSplit[1]
        }

        log.e("\(endpoint)")
        let action = HttpController.actionRegistrants.collectFirst {
            String($0.actionContext).r().matches(endpoint)
        }

        if let actor = action {
            log.v("\(actor.actionContext.endpoint)")

            if httpVerb != HttpVerb.GET {
                body = [UInt8](lines.mkString().utf8)
            }

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

        defer {
            socket.close()
        }

        let inputStream = socket.read()

        if let buffer = inputStream {
            let inputOpt = readInput(
            NSString(data: NSData(bytes: buffer,
                    length: buffer.count),
                    encoding: NSUTF8StringEncoding) as! String)

            if let input = inputOpt {
                let output = yieldOutput(input.message as! HttpMessage,
                        contentType: input.contentType)
                socket.write(output)
            }
        }
    }
}
