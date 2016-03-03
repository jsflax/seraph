import Foundation

extension Array {
    static func tabulate<T>(len: UInt8, mapper: Int -> T) -> [T] {
        return (0 ..< Int(len)).map(mapper)
    }

    static func tabulate<T>(len: Int, mapper: Int -> T) -> [T] {
        return (0 ..< len).map(mapper)
    }

    func reduce(reducer: (Element, Element) -> Element) -> Element {
        var starter = self[0]

        for i in 1 ..< count {
            starter = reducer(starter, self[i])
        }

        return starter
    }
}

// The message types are defined in RFC 6455, section 11.8.

enum MessageType: UInt8 {
    case ContinuationFrame = 0
    // TextMessage denotes a text data message. The text message payload is
    // interpreted as UTF-8 encoded text data.
    case TextMessage = 1

    // BinaryMessage denotes a binary data message.
    case BinaryMessage = 2

    // CloseMessage denotes a close control message. The optional message
    // payload contains a numeric code and text. Use the FormatCloseMessage
    // function to format a close message payload.
    case CloseMessage = 8

    // PingMessage denotes a ping control message. The optional message payload
    // is UTF-8 encoded text.
    case PingMessage = 9

    // PongMessage denotes a ping control message. The optional message payload
    // is UTF-8 encoded text.
    case PongMessage = 10
}

struct Frame {
    let isFinal: Bool
    let messageType: MessageType
    let message: [UInt8]?

    init(isFinal: Bool, messageType: MessageType, message: [UInt8]?) {
        self.isFinal = isFinal
        self.messageType = messageType
        self.message = message
    }
}

class WebSocket {
    private let socket: Socket

    let token: String

    let payload: AnyObject?
    let messageReceivedListener: (WebSocket, [UInt8]) -> Void

    internal init(socket: Socket,
                  token: String,
                  message: WsMessage?,
                  messageReceivedListener: (WebSocket, [UInt8]) -> Void) {
        self.socket = socket
        self.token = token
        self.messageReceivedListener = messageReceivedListener

        if let msg = message {
            self.payload = msg.response
        } else {
            self.payload = nil
        }
    }

    func read(bytes: [UInt8]) {
        WsReader.readFrame(bytes)
    }

    func write(message: [UInt8]) {
        log.d("Writing message: \(fromBytes(message))")

        socket.write(WsWriter.writeFrame(Frame(
        isFinal: true,
                messageType: .TextMessage,
                message: message
        )))
    }

    func isConnected() -> Bool {
        return socket.isConnected
    }

    func listen() {
        while (socket.isConnected) {
            if let bytes = socket.read() {
                let frame = WsReader.readFrame(bytes)

                switch (frame.messageType) {
                case .TextMessage, .BinaryMessage:
                    if (frame.isFinal) {
                        if let message = frame.message {
                            log.t("Read Text or Binary Message: \(fromBytes(message))")
                            messageReceivedListener(self, message)
                        } else {
                            log.e("Error writing text or binary Message")
                        }
                    } else {
                        log.e("Frame not final!")
                    }
                case .CloseMessage:
                    log.t("Writing Close, code: \(MessageType.CloseMessage)")
                    socket.write(
                    WsWriter.writeFrame(
                    Frame(isFinal: true,
                            messageType: MessageType.CloseMessage,
                            message: [UInt8]("websocket: close \(MessageType.CloseMessage) (normal)".utf8)))
                    )
                    socket.close()
                case .ContinuationFrame:
                    if (!frame.isFinal) {

                    }
                case .PingMessage, .PongMessage:
                    log.t("Writing Ping or Pong, code: \(MessageType.PongMessage)")
                    WsWriter.writeFrame(frame)
                }
            }
        }
        log.v("Socket Disconnected!")
    }
}

private class WsWriter {
    private static func tabulateBytes(inout frame: [UInt8],
                                      amount: Int,
                                      offset: Int,
                                      len: UInt8) -> Int {
        for i in 0 ..< amount {
            frame[i + offset] = ((len >> UInt8((offset - 1 - i) * 8)) & 255)
        }

        return amount + Int(offset)
    }

    private static func encode(bytes: [UInt8]) -> [UInt8] {
        log.v("Encoding message: \(bytes)")

        var frameCount = 0
        var frame = [UInt8](count: 10, repeatedValue: 0x0)

        frame[0] = 129

        switch (bytes.count) {
        case let n where n <= 125:
            frame[1] = UInt8(bytes.count)
            frameCount = 2
        case let n where n >= 126 && n <= 65535:
            frame[1] = 126
            frameCount = tabulateBytes(&frame,
                    amount: 2,
                    offset: 2,
                    len: UInt8(bytes.count))
        default:
            frame[1] = 127
            frameCount = tabulateBytes(&frame,
                    amount: 8,
                    offset: 2,
                    len: UInt8(bytes.count))
        }

        log.v("Encoded: \(frame[0 ... frameCount] + bytes)")
        return frame[0 ..< frameCount] + bytes
    }

    static func writeFrame(frame: Frame) -> [UInt8] {
        return encode(frame.message!)
    }
}

private class WsReader {
    static let FinalBit: UInt8 = 1 << 7

    private static func decode(bytes: [UInt8],
                               len: UInt8,
                               offset: Int) -> [UInt8] {
        let mask = Array(bytes[2 + offset ... 6 + offset])

        return Array<UInt8>.tabulate(len) {
            i in
            log.d("i: \(i) i % 4: \(i % 4)")
            return bytes[6 + offset + i] ^ mask[i % 4]
        }
    }

    private static func readFrame(bytes: [UInt8]) -> Frame {
        log.v("Reading Frame: \(bytes)")

        let isFinal = (bytes[0] & FinalBit) != 0
        let opCode = MessageType(rawValue: bytes[0] & 0xf)

        if let op = opCode {
            return Frame(
            isFinal: isFinal,
                    messageType: op,
                    message: {
                        switch op {
                        case .TextMessage,
                             .BinaryMessage,
                             .PingMessage,
                             .PongMessage:
                            var len = bytes[1] & 127

                            log.d("Length: \(len)")
                            switch (len) {
                            case 0:
                                return nil
                            case let n where n <= 125:
                                return decode(bytes, len: len, offset: 0)
                            case 126:
                                let data = bytes[2 ... 4]
                                len = Array<UInt8>.tabulate(data.count) {
                                    i in
                                    data[i] << UInt8(((data.count - 1 - i) * 8))
                                }.reduce({ $0 | $1 })
                                return decode(bytes, len: len, offset: 2)
                            case 127:
                                let data = bytes[2 ... 9]
                                len = Array<UInt8>.tabulate(data.count) {
                                    i in
                                    data[i] << UInt8(((data.count - 1 - i) * 8))
                                }.reduce({ $0 | $1 })
                                return decode(bytes, len: len, offset: 7)
                            default:
                                return nil
                            }
                        default:
                            return nil
                        }
                    }())
        } else {
            return Frame(isFinal: isFinal,
                    messageType: .CloseMessage,
                    message: nil)
        }
    }
}

class WsHandler {
    private let socket: WebSocket
    private let messageReceivedListener: (WebSocket, [UInt8]) -> Void

    init(socket: WebSocket,
         messageReceivedListener: (WebSocket, [UInt8]) -> Void) {
        self.socket = socket
        self.messageReceivedListener = messageReceivedListener
    }
}
