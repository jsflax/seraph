import Foundation

class Socket {
    var socketfd: Int32 = 0
    var isConnected = false

    init() {
    }

    init(socketfd: Int32) {
        self.socketfd = socketfd
    }

    init(socketfd: Int32, isConnected: Bool) {
        self.socketfd = socketfd
        self.isConnected = isConnected
    }

    /// Replacement for FD_ZERO macro
    private func fdZero(inout set: fd_set) {
        set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    /// Replacement for FD_SET macro
    private func fdSet(fd: Int32, inout set: fd_set) {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = 1 << bitOffset
        switch intOffset {
        case 0: set.fds_bits.0 = set.fds_bits.0 | mask
        case 1: set.fds_bits.1 = set.fds_bits.1 | mask
        case 2: set.fds_bits.2 = set.fds_bits.2 | mask
        case 3: set.fds_bits.3 = set.fds_bits.3 | mask
        case 4: set.fds_bits.4 = set.fds_bits.4 | mask
        case 5: set.fds_bits.5 = set.fds_bits.5 | mask
        case 6: set.fds_bits.6 = set.fds_bits.6 | mask
        case 7: set.fds_bits.7 = set.fds_bits.7 | mask
        case 8: set.fds_bits.8 = set.fds_bits.8 | mask
        case 9: set.fds_bits.9 = set.fds_bits.9 | mask
        case 10: set.fds_bits.10 = set.fds_bits.10 | mask
        case 11: set.fds_bits.11 = set.fds_bits.11 | mask
        case 12: set.fds_bits.12 = set.fds_bits.12 | mask
        case 13: set.fds_bits.13 = set.fds_bits.13 | mask
        case 14: set.fds_bits.14 = set.fds_bits.14 | mask
        case 15: set.fds_bits.15 = set.fds_bits.15 | mask
        case 16: set.fds_bits.16 = set.fds_bits.16 | mask
        case 17: set.fds_bits.17 = set.fds_bits.17 | mask
        case 18: set.fds_bits.18 = set.fds_bits.18 | mask
        case 19: set.fds_bits.19 = set.fds_bits.19 | mask
        case 20: set.fds_bits.20 = set.fds_bits.20 | mask
        case 21: set.fds_bits.21 = set.fds_bits.21 | mask
        case 22: set.fds_bits.22 = set.fds_bits.22 | mask
        case 23: set.fds_bits.23 = set.fds_bits.23 | mask
        case 24: set.fds_bits.24 = set.fds_bits.24 | mask
        case 25: set.fds_bits.25 = set.fds_bits.25 | mask
        case 26: set.fds_bits.26 = set.fds_bits.26 | mask
        case 27: set.fds_bits.27 = set.fds_bits.27 | mask
        case 28: set.fds_bits.28 = set.fds_bits.28 | mask
        case 29: set.fds_bits.29 = set.fds_bits.29 | mask
        case 30: set.fds_bits.30 = set.fds_bits.30 | mask
        case 31: set.fds_bits.31 = set.fds_bits.31 | mask
        default: break
        }
    }

    func read() -> [UInt8]? {
        var buff: [UInt8] = [UInt8](count: 4096, repeatedValue: 0x0)
        let readLen = ytcpsocket_pull(socketfd,
                data: &buff,
                len: 4096,
                timeout_sec: 10)
        if readLen > 0 {
            return buff
        } else {
            log.e("could not select: \(readLen)")
            if readLen == 0 {
                close()
            }
            return nil
        }
    }

    func write(data: [UInt8]) -> Bool {
        var buff = data
        return ytcpsocket_send(socketfd,
                data: &buff,
                len: data.count) > 0
    }

    func ytcpsocket_send(socketfd: Int32,
                         inout data: [UInt8],
                         len: Int) -> Int {
        var byteswrite = 0

        while (len - byteswrite > 0) {
            let writelen = Foundation.write(socketfd,
                    data,
                    len - byteswrite)
            if (writelen < 0) {
                return -1
            }

            byteswrite += writelen;
        }

        return byteswrite
    }

    private func ytcpsocket_pull(socketfd: Int32,
                                 inout data: [UInt8],
                                 len: Int,
                                 timeout_sec: Int) -> Int {
        if (timeout_sec > 0) {
            var fdset = fd_set()
            var timeout = timeval()
            timeout.tv_usec = 0
            timeout.tv_sec = timeout_sec

            fdZero(&fdset)
            fdSet(socketfd, set: &fdset)

            let ret = select(socketfd + 1, &fdset, nil, nil, &timeout);

            if (ret <= 0) {
                log.d("TIMEOUT")
                return -1
            } else {
                log.d("SELECT: \(ret)")
            }
        }

        var total_read_bytes = 0
        var read_bytes = 0

        log.d("READING")
        repeat {
            log.v("reading: total: \(total_read_bytes) read: \(read_bytes)")

            log.d("PRE_RECV")
            read_bytes = recv(socketfd, &data, len, MSG_DONTWAIT)
            log.d("POST_RECV")
            total_read_bytes += read_bytes
        } while (read_bytes > 0)

        data = Array(data[0 ... total_read_bytes])
        return total_read_bytes
    }

    func close() {
        Foundation.close(socketfd)
        isConnected = false
    }
}

class ServerSocket: Socket {
    private var host: UnsafePointer<Int8>
    private var port: UInt16

    init(host: UnsafePointer<Int8>, port: UInt16) {
        self.host = host
        self.port = port

        super.init()

        self.socketfd = ytcpsocket_listen(self.host, port: self.port)
    }

    private func ytcpsocket_connect(host: UnsafePointer<Int8>,
                                    port: UInt16,
                                    timeout: Int) -> Int32 {
        var sa = sockaddr_in()

        var sockfd = Int32(-1)

        let hp = gethostbyname(host)

        if (hp == nil) {
            log.error("nil host")
            return -1
        }

        bcopy(hp.memory.h_addr_list[0], &sa.sin_addr, Int(hp.memory.h_length))

        sa.sin_family = sa_family_t(hp.memory.h_addrtype)
        sa.sin_port = port.bigEndian

        sockfd = Foundation.socket(hp.memory.h_addrtype, SOCK_STREAM, 0)

        ytcpsocket_set_block(sockfd, on: 0)

        let errConnect = withUnsafePointer(&sa) {
            connect(sockfd,
                    UnsafePointer($0),
                    socklen_t(sizeofValue(sa)))
        }

        if errConnect < 0 {
            log.error("could not connect")
            return errConnect
        }

        var fdwrite = fd_set()
        var tvSelect = timeval()

        fdZero(&fdwrite)
        fdSet(sockfd, set: &fdwrite)

        tvSelect.tv_sec = timeout
        tvSelect.tv_usec = 0

        let retval = select(sockfd + 1, nil, &fdwrite, nil, &tvSelect);

        if (retval < 0) {
            Foundation.close(sockfd);
            return -2;
        } else if (retval == 0) {
            //timeout
            Foundation.close(sockfd);
            return -3;
        } else {
            var error = 0;
            var errlen = UInt32(sizeof(Int32));
            getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &error, &errlen);
            if (error != 0) {
                Foundation.close(sockfd);
                return -4; //connect fail
            }
            ytcpsocket_set_block(sockfd, on: 1);
            var _set = 1;
            setsockopt(sockfd,
                    SOL_SOCKET,
                    SO_NOSIGPIPE,
                    &_set,
                    UInt32(sizeof(Int32)))
            return sockfd;
        }
    }

    private func ytcpsocket_listen(addr: UnsafePointer<Int8>,
                                   port: UInt16) -> Int32 {
        // fetch socket file descriptor
        // AF_INET refers to IPv4 Internet protocols
        // SOCK_STREAM provides sequenced, reliable, two-way, connection-
        // based byte streams
        // protocol (0) is unspecified, as SOCK_STREAM's protocol is implicit
        // socketfd is a file descriptor; a low-level integer "handle" used
        // to identify an open file (or socket in this case)
        let socketfd = Foundation.socket(AF_INET, SOCK_STREAM, 0)

        var reuseon = 1

        // set options for socket
        // SOL_SOCKET declares the level our socket filedescriptor should
        // be manipulated on
        // SO_REUSEADDR allows the reuse of local addresses on bind, unless
        // it is pre-bound
        setsockopt(socketfd,
                SOL_SOCKET,
                SO_REUSEADDR,
                &reuseon,
                UInt32(sizeofValue(reuseon)))

        // allocate sockaddr_in struct
        var serv_addr = sockaddr_in()

        // family is IPv4 Internet based
        serv_addr.sin_family = sa_family_t(AF_INET)
        // set socket in address to the ipv4 address.
        // inet_addr converts the dot notation to binary data
        // in network byte order 
        serv_addr.sin_addr.s_addr = inet_addr(addr)
        // set socket in port to the big endian value of our port int
        serv_addr.sin_port = port.bigEndian

        // using a pointer to the sockaddr, assign a name to the socket,
        // a.k.a, "bind" the socket to the address
        let err = withUnsafePointer(&serv_addr) {
            bind(socketfd,
                    UnsafePointer($0),
                    UInt32(sizeofValue(serv_addr)))
        }

        // if no error, begin listening on port
        // else return error
        if (err == 0) {
            // #listen marks the socket as a passive socket that will
            // be used to accept incoming connection requests using
            // #accept
            // "128" is the maximum length to which the queue of pending
            // connections may grow. if the queue is full, the client will
            // receive an error
            // returns 0 on success
            if (listen(socketfd, 128) == 0) {
                log.v("listening on port: \(port)")
                return socketfd
            } else {
                log.e("listen error")
                return -2
            }
        } else {
            log.e("bind error: \(err)")
            return -1
        }
    }


    private func ytcpsocket_accept(onsocketfd: Int32) -> Int32 {
        // allocate struct for size of address
        var clilen = socklen_t();
        // allocate struct for client socket address in
        var cli_addr = sockaddr_in();

        // accept a connection on a socket
        // onsocketfd is our current server socket that is passively listening
        // the client address pointer will be written to with the
        // connecting address
        // returns a new socket file descriptor for the client
        let newsockfd = withUnsafePointer(&cli_addr) {
            Foundation.accept(onsocketfd, UnsafeMutablePointer($0), &clilen)
        }

        // if the file descriptor is greater than zero,
        // return the new descriptor
        if (newsockfd > 0) {
            return newsockfd;
        } else {
            log.e("could not accept socket")
            return -1;
        }
    }

    private func ytcpsocket_set_block(socket: Int32, on: Int32) -> Int32 {
        var flags = fcntl(socket, F_GETFL, 0);
        if (on == 0) {
            return fcntl(socket, F_SETFL, flags | O_NONBLOCK);
        } else {
            flags &= ~O_NONBLOCK;
            return fcntl(socket, F_SETFL, flags);
        }
    }

    func accept() -> Socket? {
        let newsockFd = ytcpsocket_accept(socketfd)
        if newsockFd > 0 {
            return Socket(socketfd: newsockFd, isConnected: true)
        } else {
            return nil
        }
    }
}
