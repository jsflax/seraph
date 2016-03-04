import Foundation


class TestHttpController: HttpController {
    override init() {
        super.init()
        self.register(
        +"/hello",
                handler: {
                    req in
                    log.e("\(req.params)")
                    return HttpMessage(response: [UInt8]("hello world".utf8))
                },
                contentType: ContentType.TextHtml,
                verbs: HttpVerb.GET
        )

        self.register(
        +"/user/\(~"token")/",
        handler: {
            req in
            let response = [
                    "success": true,
                    "data": [
                            "name": "Jason",
                            "email": "jsflax@seraph.com",
                            "token": req.params["token"]!
                    ]
            ]

            return HttpMessage(response: [UInt8](JSON(response).utf8))
        },
        contentType: ContentType.ApplicationJson,
        verbs: HttpVerb.GET
        )
    }
}

class TestWsController: WsController {
    override init() {
        super.init()

        self.register(
        +"/ws",
                handler: {
                    req in
                    let response = [
                            "success": true,
                    ]

                    return WsMessage(response: response)
                },
                contentType: ContentType.ApplicationJson,
                verbs: HttpVerb.GET
        )
    }
}


class TestWsIoManager: WsProtocolManager {
    var sockets: [String:WebSocket] = [:]

    override func onMessageReceived(socket: WebSocket, message: [UInt8]) {
        log.i("Message received!")

        broadcastMessage(message,
                sockets: sockets.filter({ $0.0 != socket.token }).map({ $0.1 }))
    }

    override func onSocketConnected(socket: WebSocket) {
        sockets[socket.token] = socket
    }
}


func test_WsIoManager() {
    let testController = TestWsController()
    let manager = TestWsIoManager(host: "192.168.0.182", port: 8888)
    manager.loop()
    wait()
}

func test_HttpIoManager() {
    let testController = TestHttpController()
    let ioManager = HttpProtocolManager(host: "127.0.0.1", port: 8888)
    ioManager.loop()
    wait()
}

test_WsIoManager()
