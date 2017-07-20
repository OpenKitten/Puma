#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Lynx

fileprivate let httpOpening = [UInt8]("HTTP/".utf8)
fileprivate let contentLengthKey: HeaderKey = "Content-Length"

public class ResponsePlaceholder {
    /// Creates a new placeholder
    init() { }
    
    /// The pointer in which the pointer is moved
    var pointer: UnsafePointer<UInt8>!
    
    /// The remaining length of data behind the pointer
    var length: Int!
    
    /// The current offset from the pointer
    var currentPosition: Int = 0
    
    /// The leftover buffer from previous parsing attempts
    var leftovers = [UInt8]()
    
    /// If `true`, the first line of HTTP is parsed
    var topLineComplete = false
    
    
    /// If false, parsing failed and it needs to wait until the next package anymore
    ///
    /// This puts the remaining data in the leftovers
    ///
    /// TODO: Use leftovers for parsing
    var parsable = true {
        didSet {
            if parsable == false {
                self.leftovers.append(contentsOf: UnsafeBufferPointer(start: pointer, count: length))
                return
            }
        }
    }
    
    /// If true, parsing can proceed
    fileprivate var proceedable: Bool {
        return correct && parsable
    }
    
    /// Defines whether the HTTP Request is correct
    var correct = true
    
    /// If true, all components of a response have been parsed
    var complete = false
    
    /// The response's Status code
    var status: Status?
    
    /// All of the response headers
    var headers: Headers?
    
    /// The full length of the body, including all that hasn't been received yet
    var contentLength = 0
    
    /// The currently copiedbodyLength
    var bodyLength = 0
    
    /// A buffer in which the body is kept
    var body: UnsafeMutablePointer<UInt8>?
    
    /// Cleans up the RequestPlaceholder for a next response
    func empty() {
        self.body = nil
        contentLength = 0
        bodyLength = 0
    }
    
    /// Parses the data at the pointer to proceed building the response
    func parse(_ ptr: UnsafePointer<UInt8>, len: Int) {
        self.pointer = ptr
        self.length = len
        
        func parseStatusCode() {
            guard len > 14 else {
                return
            }
            
            guard memcmp(ptr, httpOpening, httpOpening.count) == 0 else {
                return
            }
            
            // " "
            guard ptr[httpOpening.count &+ 3] == 0x20 else {
                return
            }
            
            let httpCode: [UInt8] = [
                ptr[httpOpening.count &+ 4],
                ptr[httpOpening.count &+ 5],
                ptr[httpOpening.count &+ 6]
            ]
            
            guard let codeString = String(bytes: httpCode, encoding: .utf8), let status = Int(codeString), ptr[httpOpening.count &+ 7] == 0x20 else {
                return
            }
            
            self.status = Status(status)
            
            length! -= httpOpening.count &+ 6
            pointer = pointer.advanced(by: httpOpening.count &+ 6)
            
            pointer.peek(until: 0x0a, length: &length, offset: &currentPosition)
        }
        
        func parseHeaders() {
            let start = pointer
            
            while true {
                // \n
                pointer.peek(until: 0x0a, length: &length, offset: &currentPosition)
                
                guard currentPosition > 0 else {
                    self.headers = Headers()
                    return
                }
                
                if length > 1, pointer[-2] == 0x0d, pointer[0] == 0x0d, pointer[1] == 0x0a {
                    defer {
                        pointer = pointer.advanced(by: 2)
                        length = length &- 2
                    }
                    
                    self.headers = Headers(serialized: UnsafeBufferPointer(start: start, count: start!.distance(to: pointer)))
                    return
                }
            }
        }
        
        if status == nil {
            parseStatusCode()
        }
        
        if proceedable, headers == nil {
            parseHeaders()
            
            if let cl = headers?[contentLengthKey], let contentLength = Int(cl.stringValue) {
                self.contentLength = contentLength
                self.body = UnsafeMutablePointer<UInt8>.allocate(capacity: self.contentLength)
            }
        }
        
        if length > 0, let body = body {
            let copiedLength = min(length, contentLength &- bodyLength)
            memcpy(body.advanced(by: bodyLength), pointer, copiedLength)
            length = length &- copiedLength
            self.bodyLength = bodyLength &+ copiedLength
            pointer = pointer.advanced(by: copiedLength)
        }
        
        if bodyLength == contentLength {
            complete = true
        }
    }
    
    func makeResponse() -> Response? {
        guard complete,
            let status = status,
            let headers = headers else {
            return nil
        }
        
        if let body = body {
            return Response(status: status, headers: headers, body: Body(pointingTo: UnsafeMutableBufferPointer(start: body, count: contentLength), deallocating: true))
        } else {
            return Response(status: status, headers: headers)
        }
    }
    
    deinit {
        body?.deallocate(capacity: self.contentLength)
    }
}

// MARK - Copy for swift inline optimization

extension UnsafePointer where Pointee == UInt8 {
    fileprivate func string(until length: inout Int) -> String? {
        return String(bytes: buffer(until: &length), encoding: .utf8)
    }
    
    fileprivate func buffer(until length: inout Int) -> UnsafeBufferPointer<UInt8> {
        guard length > 0 else {
            return UnsafeBufferPointer<UInt8>(start: nil, count: 0)
        }
        
        return UnsafeBufferPointer(start: self.advanced(by: -length), count: length)
    }
    
    fileprivate mutating func peek(until byte: UInt8, length: inout Int!, offset: inout Int) {
        offset = 0
        defer { length = length &- offset }
        
        while offset &+ 4 < length {
            if self[0] == byte {
                offset = offset &+ 1
                self = self.advanced(by: 1)
                return
            }
            if self[1] == byte {
                offset = offset &+ 2
                self = self.advanced(by: 2)
                return
            }
            if self[2] == byte {
                offset = offset &+ 3
                self = self.advanced(by: 3)
                return
            }
            offset = offset &+ 4
            defer { self = self.advanced(by: 4) }
            if self[3] == byte {
                return
            }
        }
        
        if offset < length, self[0] == byte {
            offset = offset &+ 1
            self = self.advanced(by: 1)
            return
        }
        if offset &+ 1 < length, self[1] == byte {
            offset = offset &+ 2
            self = self.advanced(by: 2)
            return
        }
        if offset &+ 2 < length, self[2] == byte {
            offset = offset &+ 3
            self = self.advanced(by: 3)
            return
        }
        
        self = self.advanced(by: length &- offset)
        offset = length
    }
}
