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

extension ArraySlice {
    func reduce(reducer: (Element, Element) -> Element) -> Element {
        var starter = self[0]

        for i in 1 ..< count {
            starter = reducer(starter, self[i])
        }

        return starter
    }
}

// The message types are defined in RFC 6455, section 11.8.
// Also known as OP Codes
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

// Structure of a received frame from websocket protocol RFC 6455
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

        socket.write(
            WsWriter.writeFrame(
                Frame(isFinal: true,
                      messageType: .TextMessage,
                      message: message
                     )
            ))
    }

    func isConnected() -> Bool {
        return socket.isConnected
    }

    // continually listen to the accepted socket
    func listen() {
        while (socket.isConnected) {
            // read bytes from the socket. this is blocking.
            // if not nil, enter the parsing process
            if let bytes = socket.read() {
                // read the frame sent to the server
                let frame = WsReader.readFrame(bytes)

                // write to the socket based on the frame's message type
                switch (frame.messageType) {
                case .TextMessage, .BinaryMessage:
                    if (frame.isFinal) {
                        if let message = frame.message {
                            log.v(
                                "Read Text or Binary Message: " +
                                  "\(fromBytes(message))"
                            )
                            messageReceivedListener(self, message)
                        } else {
                            log.e("Error writing text or binary Message")
                        }
                    } else {
                        log.e("Frame not final!")
                    }
                case .CloseMessage:
                    log.v("Writing Close, code: \(MessageType.CloseMessage)")
                    socket.write(
                    WsWriter.writeFrame(
                    Frame(isFinal: true,
                          messageType: MessageType.CloseMessage,
                          message: [UInt8](
                          [UInt8]("websocket: close ".utf8) +
                                "\(MessageType.CloseMessage) (normal)".utf8)
                         ))
                    )
                    socket.close()
                case .ContinuationFrame:
                    // TODO: Handle continuation frame
                    if (!frame.isFinal) {

                    }
                case .PingMessage, .PongMessage:
                    log.t("Writing Ping or Pong, code: " +
                          "\(MessageType.PongMessage)")
                    WsWriter.writeFrame(frame)
                }
            }
        }
        
        log.v("Socket Disconnected!")
    }
}

/* READING AND WRITING FRAME DATA.
   This wire format for the data transfer part is described by the ABNF
   [RFC5234] given in detail in this section.  (Note that, unlike in
   other sections of this document, the ABNF in this section is
   operating on groups of bits.  The length of each group of bits is
   indicated in a comment.  When encoded on the wire, the most
   significant bit is the leftmost in the ABNF).  A high-level overview
   of the framing is given in the following figure.  In a case of
   conflict between the figure below and the ABNF specified later in
   this section, the figure is authoritative.

      0                   1                   2                   3
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-------+-+-------------+-------------------------------+
     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
     | |1|2|3|       |K|             |                               |
     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
     |     Extended payload length continued, if payload len == 127  |
     + - - - - - - - - - - - - - - - +-------------------------------+
     |                               |Masking-key, if MASK set to 1  |
     +-------------------------------+-------------------------------+
     | Masking-key (continued)       |          Payload Data         |
     +-------------------------------- - - - - - - - - - - - - - - - +
     :                     Payload Data continued ...                :
     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
     |                     Payload Data continued ...                |
     +---------------------------------------------------------------+
*/
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
        // fetch the mask
        // messages are encoding using a bitmask that we will have
        // to unravel
        let mask = Array(bytes[2 + offset ... 6 + offset])

        // tabulate the data, unmasking the message using bitwise XOR
        return Array<UInt8>.tabulate(len) {
                         bytes[6 + offset + $0] ^ mask[$0 % 4]
        }
    }

    // read a frame received over the wire
    // -parameter bytes: frame bytes
    // return: @Frame struct
    private static func readFrame(bytes: [UInt8]) -> Frame {
        log.v("Reading Frame: \(bytes)")

        // determine if this is the final frame or a continuation frame
        // @see: RFC 6455 p28
        let isFinal = (bytes[0] & FinalBit) != 0

        // determine the op code of this frame
        let opCode = MessageType(rawValue: bytes[0] & 0xf)

        // if we were sent a valid op code, begin parsing the frame,
        // returning the result regardless of message success
        if let op = opCode {
            return Frame(
                    isFinal: isFinal,
                    messageType: op,
                    message: {
                        switch op {
                        case .TextMessage, .BinaryMessage,
                               .PingMessage, .PongMessage:
                            // determine the length of this frame
                            var len = bytes[1] & 127

                            log.d("Websocket data length: \(len)")

                            // based on the websocket protocol, the length means
                            // several different possibilities.
                            // if 0, this is an invalid frame
                            //
                            // if n where n is less than or equal to 125,
                            // this is the actual length of our message,
                            // which can be decoded in the subsequent bytes
                            //
                            // if 126, the length is actually encoded in the
                            // following 2 bytes, and the message follows
                            // subsequently
                            //
                            // if 127, the length is actually encoded in the
                            // following 7 bytes, and the message follows
                            // subsequently
                            switch (len) {
                            case 0:
                                return nil
                            case let n where n <= 125:
                                // decode the message
                                return decode(bytes, len: len, offset: 0)
                            case 126:
                                // slice the next 2 bytes and
                                // calculate the length by bitwise ORing
                                len = Array(bytes[2 ..< 4]).reduce({$0 | $1})
                                                                       
                                // decode the message
                                return decode(bytes, len: len, offset: 2)
                            case 127:
                                // slice the next 7 bytes and calculate
                                // the length by bitwise ORing
                                len = Array(bytes[2 ..< 9]).reduce({$0 | $1})

                                // decode the message
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
