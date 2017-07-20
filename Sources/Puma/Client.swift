#if (os(macOS) || os(iOS))
    import Security
    import Darwin
#if OPENSSL
    import KittenCTLS
#endif
#else
    import KittenCTLS
    import Glibc
#endif

import Foundation
import Lynx
import Schrodinger

public enum HTTPClient {
    public static func sync(to host: String, port: UInt16 = 80) throws -> SyncHTTPClient {
        return try SyncHTTPClient(to: host, port: port)
    }
}

class FutureHolder {
    var future = Future<Response>()
}

open class SyncHTTPClient {
    var futureHolder: FutureHolder
    var client: TCPClient
    let host: String
    
    public init(to host: String, port: UInt16? = nil, ssl: Bool = false) throws {
        self.host = host
        
        var responseProgress = ResponsePlaceholder()
        var futureHolder = FutureHolder()
        
        func onRead(pointer: UnsafePointer<UInt8>, count: Int) {
            responseProgress.parse(pointer, len: count)
            
            if responseProgress.complete, let response = responseProgress.makeResponse() {
                do {
                    try futureHolder.future.complete { response }
                } catch {
                    print("The response future was already completed. Please don't manually complete futures.")
                }
                responseProgress.empty()
            }
        }
        
        self.futureHolder = futureHolder
        
        if ssl {
            let client = try TCPSSLClient(hostname: host, port: port ?? 443, onRead: onRead)
            self.client = client
        } else {
            self.client = try TCPClient(hostname: host, port: port ?? 80, onRead: onRead)
        }
    }
    
    public static func send(_ request: Request, toHost host: String, atPort port: UInt16? = nil, securely ssl: Bool = false, timeoutAfter timeout: Int = 30) throws -> Response {
        let client = try SyncHTTPClient(to: host, port: port, ssl: ssl)
        return try client.send(request, timeoutAfter: timeout)
    }
    
    public func send(_ request: Request, timeoutAfter timeout: Int = 30) throws -> Response {
        defer {
            self.futureHolder.future = Future<Response>()
        }
        
        request.headers["Host"] = HeaderValue(host)
        
        try client.send(request)
        
        return try self.futureHolder.future.await(for: .seconds(timeout))
    }
}
