//
// Created by Jason Flax on 2/29/16.
//

import Foundation


class IOManager {
    let serverSocket: ServerSocket
    var isRunning: Bool = false

    init(host: UnsafePointer<Int8>, port: UInt16) {
        self.serverSocket = ServerSocket(host: host, port: port)
    }

    internal func ioLoop(socket: Socket) {
        preconditionFailure("This method must be overridden")
    }

    private func socketLoop(server: ServerSocket) {
        log.trace("Awaiting request")
        // accept client socket. this is a blocking method
        let socketOpt = server.accept();

        // if socket was accepted, run the IO loop 
        if let socket = socketOpt {
            async {
                self.ioLoop(socket)
            }
        }
    }

    func shutdown() {
        self.isRunning = false;
        // TODO: add server.close
    }

    func loop() {
        self.isRunning = true;
        // begin loop on new thread
        async {
            // run until shutdown
            while (self.isRunning) {
                // run socketloop
                self.socketLoop(self.serverSocket)
            }
        }
    }
}
