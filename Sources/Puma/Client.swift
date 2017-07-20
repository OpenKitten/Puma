#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Foundation
import Lynx
import Schrodinger

public enum HTTPClient {
    public static func sync(to host: String, port: UInt16 = 80) throws -> SyncHTTPClient {
        return try SyncHTTPClient(to: host, port: port)
    }
}

open class SyncHTTPClient {
    var future = Future<Response>()
//    var responseProgoress = ResponsePlaceholder()
    let client: TCPClient
    let host: String
    
    public init(to host: String, port: UInt16 = 80) throws {
        self.host = host
        self.client = try TCPClient(hostname: host, port: port) { pointer, count in
            var data = [UInt8](repeating: 0, count: count)
            memcpy(&data, pointer, count)
            
            print(String(bytes: data, encoding: .utf8)!)
//            responseProgress.parse(ptr, len: len)
//
//            if responseProgress.complete, let response = responseProgress.makeRequest() {
//                future.complete { response }
//                responseProgress.empty()
//            }
        }
    }
    
    func send(_ request: Request, for timeout: Int = 30) throws -> Response {
        defer {
            future = Future<Response>()
        }
        
        request.headers["Host"] = HeaderValue(host)
        
        try client.send(request)
        
        return try future.await(for: .seconds(timeout))
    }
}
