//
// Created by Jason Flax on 3/3/16.
//

import Foundation


private func rotateLeft(v: UInt8, _ n: UInt8) -> UInt8 {
    return ((v << n) & 0xFF) | (v >> (8 - n))
}

private func rotateLeft(v: UInt16, _ n: UInt16) -> UInt16 {
    return ((v << n) & 0xFFFF) | (v >> (16 - n))
}

private func rotateLeft(v: UInt32, _ n: UInt32) -> UInt32 {
    return ((v << n) & 0xFFFFFFFF) | (v >> (32 - n))
}

private func rotateLeft(x: UInt64, _ n: UInt64) -> UInt64 {
    return (x << n) | (x >> (64 - n))
}

/// Array of bytes, little-endian representation. Don't use if not necessary.
/// I found this method slow
private func arrayOfBytes<T>(value: T, length: Int? = nil) -> [UInt8] {
    let totalBytes = length ?? sizeof(T)

    let valuePointer = UnsafeMutablePointer<T>.alloc(1)
    valuePointer.memory = value

    let bytesPointer = UnsafeMutablePointer<UInt8>(valuePointer)
    var bytes = [UInt8](count: totalBytes, repeatedValue: 0)
    for j in 0 ..< min(sizeof(T), totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).memory
    }

    valuePointer.destroy()
    valuePointer.dealloc(1)

    return bytes
}

private protocol BitshiftOperationsType {
    func <<(lhs: Self, rhs: Self) -> Self

    func >>(lhs: Self, rhs: Self) -> Self

    func <<=(inout lhs: Self, rhs: Self)

    func >>=(inout lhs: Self, rhs: Self)
}

private protocol ByteConvertible {
    init(_ value: UInt8)
    init(truncatingBitPattern: UInt64)
}

extension Int: BitshiftOperationsType, ByteConvertible {
}

extension Int8: BitshiftOperationsType, ByteConvertible {
}

extension Int16: BitshiftOperationsType, ByteConvertible {
}

extension Int32: BitshiftOperationsType, ByteConvertible {
}

extension Int64: BitshiftOperationsType, ByteConvertible {
    init(truncatingBitPattern value: UInt64) {
        self = Int64(bitPattern: value)
    }
}

extension UInt: BitshiftOperationsType, ByteConvertible {
}

extension UInt8: BitshiftOperationsType, ByteConvertible {
}

extension UInt16: BitshiftOperationsType, ByteConvertible {
}

extension UInt32: BitshiftOperationsType, ByteConvertible {
}

extension UInt64: BitshiftOperationsType, ByteConvertible {
    init(truncatingBitPattern value: UInt64) {
        self = value
    }
}

/// Initialize integer from array of bytes.
/// This method may be slow
private func integerWithBytes<T:IntegerType where T: ByteConvertible, T: BitshiftOperationsType>(bytes: [UInt8]) -> T {
    var bytes = bytes.reverse() as Array<UInt8> //FIXME: check it this is equivalent of Array(...)
    if bytes.count < sizeof(T) {
        let paddingCount = sizeof(T) - bytes.count
        if (paddingCount > 0) {
            bytes += [UInt8](count: paddingCount, repeatedValue: 0)
        }
    }

    if sizeof(T) == 1 {
        return T(truncatingBitPattern: UInt64(bytes.first!))
    }

    var result: T = 0
    for byte in bytes.reverse() {
        result = result << 8 | T(byte)
    }
    return result
}

private func toUInt32Array(slice: ArraySlice<UInt8>) -> Array<UInt32> {
    var result = Array<UInt32>()
    result.reserveCapacity(16)

    for idx in slice.startIndex.stride(to: slice.endIndex, by: sizeof(UInt32)) {
        let val1: UInt32 = (UInt32(slice[idx.advancedBy(3)]) << 24)
        let val2: UInt32 = (UInt32(slice[idx.advancedBy(2)]) << 16)
        let val3: UInt32 = (UInt32(slice[idx.advancedBy(1)]) << 8)
        let val4: UInt32 = UInt32(slice[idx])
        let val: UInt32 = val1 | val2 | val3 | val4
        result.append(val)
    }
    return result
}

private func toUInt64Array(slice: ArraySlice<UInt8>) -> Array<UInt64> {
    var result = Array<UInt64>()
    result.reserveCapacity(32)
    for idx in slice.startIndex.stride(to: slice.endIndex, by: sizeof(UInt64)) {
        var val: UInt64 = 0
        val |= UInt64(slice[idx.advancedBy(7)]) << 56
        val |= UInt64(slice[idx.advancedBy(6)]) << 48
        val |= UInt64(slice[idx.advancedBy(5)]) << 40
        val |= UInt64(slice[idx.advancedBy(4)]) << 32
        val |= UInt64(slice[idx.advancedBy(3)]) << 24
        val |= UInt64(slice[idx.advancedBy(2)]) << 16
        val |= UInt64(slice[idx.advancedBy(1)]) << 8
        val |= UInt64(slice[idx.advancedBy(0)]) << 0
        result.append(val)
    }
    return result
}

extension UInt64 {
    public func bytes(totalBytes: Int = sizeof(UInt64)) -> [UInt8] {
        return arrayOfBytes(self, length: totalBytes)
    }

    public static func withBytes(bytes: ArraySlice<UInt8>) -> UInt64 {
        return UInt64.withBytes(Array(bytes))
    }

    /** Int with array bytes (little-endian) */
    public static func withBytes(bytes: [UInt8]) -> UInt64 {
        return integerWithBytes(bytes)
    }
}

extension Int {
    public func bytes(totalBytes: Int = sizeof(Int)) -> [UInt8] {
        return arrayOfBytes(self, length: totalBytes)
    }

    public static func withBytes(bytes: ArraySlice<UInt8>) -> Int {
        return Int.withBytes(Array(bytes))
    }

    /** Int with array bytes (little-endian) */
    public static func withBytes(bytes: [UInt8]) -> Int {
        return integerWithBytes(bytes)
    }
}

private func CS_AnyGenerator<Element>(body: () -> Element?) -> AnyGenerator<Element> {
    return AnyGenerator(body: body)
}

struct BytesSequence: SequenceType {
    let chunkSize: Int
    let data: [UInt8]

    func generate() -> AnyGenerator<ArraySlice<UInt8>> {

        var offset: Int = 0

        return CS_AnyGenerator {
            let end = min(self.chunkSize, self.data.count - offset)
            let result = self.data[offset ..< offset + end]
            offset += result.count
            return result.count > 0 ? result : nil
        }
    }
}

internal protocol HashProtocol {
    var message: Array<UInt8> { get }

    /** Common part for hash calculation. Prepare header data. */
    func prepare(len: Int) -> Array<UInt8>
}

extension HashProtocol {

    func prepare(len: Int) -> Array<UInt8> {
        var tmpMessage = message

        // Step 1. Append Padding Bits
        tmpMessage.append(0x80) // append one bit (UInt8 with one bit) to message

        // append "0" bit until message length in bits ≡ 448 (mod 512)
        var msgLength = tmpMessage.count
        var counter = 0

        while msgLength % len != (len - 8) {
            counter += 1
            msgLength += 1
        }

        tmpMessage += Array<UInt8>(count: counter, repeatedValue: 0)
        return tmpMessage
    }
}

private class Sha1: HashProtocol {
    static let size: Int = 20
    // 160 / 8
    let message: [UInt8]

    init(_ message: [UInt8]) {
        self.message = message
    }

    private let h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

    func calculate() -> [UInt8] {
        var tmpMessage = self.prepare(64)

        // hash values
        var hh = h

        // append message length, in a 64-bit big-endian integer. So now the message length is a multiple of 512 bits.
        tmpMessage += (self.message.count * 8).bytes(64 / 8)

        // Process the message in successive 512-bit chunks:
        let chunkSizeBytes = 512 / 8 // 64
        for chunk in BytesSequence(chunkSize: chunkSizeBytes, data: tmpMessage) {
            // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15, big-endian
            // Extend the sixteen 32-bit words into eighty 32-bit words:
            var M: [UInt32] = [UInt32](count: 80, repeatedValue: 0)
            for x in 0 ..< M.count {
                switch (x) {
                case 0 ... 15:
                    let start = chunk.startIndex + (x * sizeofValue(M[x]))
                    let end = start + sizeofValue(M[x])
                    let le = toUInt32Array(chunk[start ..< end])[0]
                    M[x] = le.bigEndian
                    break
                default:
                    M[x] = rotateLeft(M[x - 3] ^ M[x - 8] ^ M[x - 14] ^ M[x - 16], 1) //FIXME: n:
                    break
                }
            }

            var A = hh[0]
            var B = hh[1]
            var C = hh[2]
            var D = hh[3]
            var E = hh[4]

            // Main loop
            for j in 0 ... 79 {
                var f: UInt32 = 0;
                var k: UInt32 = 0

                switch (j) {
                case 0 ... 19:
                    f = (B & C) | ((~B) & D)
                    k = 0x5A827999
                    break
                case 20 ... 39:
                    f = B ^ C ^ D
                    k = 0x6ED9EBA1
                    break
                case 40 ... 59:
                    f = (B & C) | (B & D) | (C & D)
                    k = 0x8F1BBCDC
                    break
                case 60 ... 79:
                    f = B ^ C ^ D
                    k = 0xCA62C1D6
                    break
                default:
                    break
                }

                let temp = (rotateLeft(A, 5) &+ f &+ E &+ M[j] &+ k) & 0xffffffff
                E = D
                D = C
                C = rotateLeft(B, 30)
                B = A
                A = temp
            }

            hh[0] = (hh[0] &+ A) & 0xffffffff
            hh[1] = (hh[1] &+ B) & 0xffffffff
            hh[2] = (hh[2] &+ C) & 0xffffffff
            hh[3] = (hh[3] &+ D) & 0xffffffff
            hh[4] = (hh[4] &+ E) & 0xffffffff
        }

        // Produce the final hash value (big-endian) as a 160 bit number:
        var result = [UInt8]()
        result.reserveCapacity(hh.count / 4)
        hh.foreach {
            let item = $0.bigEndian
            result += [UInt8(item & 0xff), UInt8((item >> 8) & 0xff), UInt8((item >> 16) & 0xff), UInt8((item >> 24) & 0xff)]
        }
        return result
    }
}

extension String {
    func sha1() -> [UInt8] {
        return Sha1([UInt8](self.utf8)).calculate()
    }
}
