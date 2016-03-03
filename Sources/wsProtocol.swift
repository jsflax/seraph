//
// Created by Jason Flax on 3/2/16.
//

import Foundation

private let magicHashString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

class WsProtocolManager: IOManager {

    func onMessageReceived(socket: WebSocket, message: [UInt8]) {
        preconditionFailure("This method must be overridden")
    }

    func onSocketConnected(socket: WebSocket) {
        preconditionFailure("This method must be overridden")
    }

    func broadcastMessage(message: [UInt8], sockets: [WebSocket]) {
        sockets.foreach {
            socket in
            if (socket.isConnected()) {
                socket.write(message)
            }
        }
    }

    /**
      * Handle the input and write to the output stream,
      * returning data to the client.
      *
      * @param out output stream we are writing to
      */
    private func completeHandshake(socket: Socket, socketKey: String?) {
        var out = ""
        // if successful, write the output following http 1.1 specs
        if let key = socketKey {
            out += "HTTP/1.1 101 Switching Protocols\r\n"

            out += "Upgrade: websocket\r\n"
            out += "Connection: Upgrade\r\n"
            out += "Sec-WebSocket-Accept: \(key)\r\n"

            out += "\r\n"
        } else {
            out += "HTTP/1.1 400 Bad request\r\n"
            out += "Server: WebServer\r\n"
            out += "Connection: close\r\n"
            out += "\r\n"
        }

        socket.write([UInt8](out.utf8))
    }

    /**
      * Read the input from the input stream.
      *
      * @param bufferedReader input stream
      * @return hand-shook socket key
      */
    private func initiateHandshake(input: String) -> (String, WsMessage)? {
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

        // this line also starts with the http method
        // check our HttpMethods enum for a valid httpMethod
        let httpMethod = HttpVerb.values.collectFirst {
            line.hasPrefix(String($0))
        }

        // if it is not a valid http method, short circuit
        if (httpMethod == nil) {
            log.e("Not a valid http method: \(line)")
            return nil
        }

        var webSocketKey: String = ""
        var headers: [String:String] = [:]

        while (line != "") {
            log.verbose(line)

            let webSocketKeyKey = "sec-websocket-key: "
            if (line.lowercaseString.hasPrefix(webSocketKeyKey)) {
                webSocketKey = line[webSocketKeyKey.characters.count ..<
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

            line = lines.removeFirst()
            log.v(line)
        }

        log.v("Headers: \(headers)")
        var queryParameters: String? = nil

        if endpoint.characters.contains("?") {
            let epSplit = endpoint.characters.split {
                $0 == "?"
            }.map {
                String($0)
            }

            endpoint = epSplit[0]
            queryParameters = epSplit[1]
        }

        let action = WsControllerUntyped.actionRegistrants.collectFirst {
            String($0.actionContext).r().matches(endpoint)
        }


        // if it is defined, read the body and return in the input
        // else, return None, as we aren't going to handle this further
        if let actor = action {
            log.v("\(actor.actionContext.endpoint)")

            let socketKey = base64("\(webSocketKey)\(magicHashString)".sha1())

            if let verb = actor.verbs.find({ httpMethod! == $0 }) {
                return (socketKey,
                        (Input(endpoint: endpoint,
                                body: [],
                                queryParams: queryParameters,
                                cookie: nil,
                                httpVerb: verb,
                                headers: headers,
                                action: actor,
                                contentType: actor.contentType
                        ).message as! WsMessage))
            } else {
                return nil
            }
        } else {
            log.e("invalid endpoint: \(endpoint)")
            return nil
        }
    }

    private func shake(socket: Socket) -> WebSocket? {
        let keyAndPayloadOpt = self.initiateHandshake(String(bytes: socket.read()!,
                encoding: NSUTF8StringEncoding
        )!
        )

        if let keyAndPayload = keyAndPayloadOpt {
            self.completeHandshake(socket, socketKey: keyAndPayload.0)
            return WebSocket(socket: socket,
                    token: keyAndPayload.0,
                    message: keyAndPayload.1,
                    messageReceivedListener: onMessageReceived)
        } else {
            self.completeHandshake(socket, socketKey: nil)
            return nil
        }
    }

    override func ioLoop(socket: Socket) {
        if let websocket = shake(socket) {

            async {
                websocket.listen()
            }

            onSocketConnected(websocket)
        } else {
            log.e("Could not fetch key or payload")
            socket.close()
        }
    }
}
