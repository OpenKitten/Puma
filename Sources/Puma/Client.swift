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
    
    public enum Error : Swift.Error {
        case invalidHTTPURL
    }
}

class FutureHolder {
    var future = Future<Response>()
}

open class SyncHTTPClient {
    var futureHolder: FutureHolder
    var client: TCPClient!
    public var cookies = Cookies()
    let host: String
    let followRedirect: Int
    
    public init(to host: String, port: UInt16? = nil, ssl: Bool = false, followRedirect: Int = 1) throws {
        self.host = host
        self.followRedirect = followRedirect
        
        var responseProgress = ResponsePlaceholder()
        var futureHolder = FutureHolder()
        
        self.futureHolder = futureHolder
        
        func onRead(pointer: UnsafePointer<UInt8>, count: Int) {
            responseProgress.parse(pointer, len: count)
            
            if responseProgress.complete, let response = responseProgress.makeResponse() {
                do {
                    try self.futureHolder.future.complete { response }
                } catch {
                    print("The response future was already completed. Please don't manually complete futures.")
                }
                responseProgress.empty()
            }
        }
        
        if ssl {
            let client = try TCPSSLClient(hostname: host, port: port ?? 443, onRead: onRead)
            try client.connect()
            self.client = client
        } else {
            let client = try TCPClient(hostname: host, port: port ?? 80, onRead: onRead)
            try client.connect()
            self.client = client
        }
    }
    
    public static func send(_ request: Request, to url: String, followRedirect: Int = 1) throws -> Response {
        guard let url = URL(string: url) else {
            throw HTTPClient.Error.invalidHTTPURL
        }
        
        let ssl: Bool
        
        if url.scheme == "http" {
            ssl = false
        } else if url.scheme == "https" {
            ssl = true
        } else {
            throw HTTPClient.Error.invalidHTTPURL
        }
        
        let port = url.port ?? (ssl ? 443 : 80)
        
        guard port < Int(UInt16.max) else {
            throw HTTPClient.Error.invalidHTTPURL
        }
        
        return try SyncHTTPClient.send(request, toHost: url.host ?? "127.0.0.1", atPort: UInt16(port), securely: ssl, followRedirect: followRedirect)
    }
    
    public static func send(_ request: Request, toHost host: String, atPort port: UInt16? = nil, securely ssl: Bool = false, timeoutAfter timeout: Int = 30, followRedirect: Int = 3) throws -> Response {
        let client = try SyncHTTPClient(to: host, port: port, ssl: ssl)
        let response = try client.send(request, timeoutAfter: timeout)
        
        guard response.status.code < 300 || response.status.code >= 400 else {
            guard let url = String(response.headers["Location"]), followRedirect > 0 else {
                return response
            }
            
            request.cookies += client.cookies
            
            return try SyncHTTPClient.send(request, to: url, followRedirect: followRedirect - 1)
        }
        
        return response
    }
    
    public func send(_ request: Request, timeoutAfter timeout: Int = 30, followRedirect: Int = 3) throws -> Response {
        defer {
            self.futureHolder.future = Future<Response>()
        }
        
        request.headers["Host"] = HeaderValue(host)
        
        try client.send(request)
        
        let response = try self.futureHolder.future.await(for: .seconds(timeout))
        
        self.cookies += response.cookies
        
        return response
    }
}
