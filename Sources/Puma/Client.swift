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
    var responseProgress = ResponsePlaceholder()
    var client: TCPClient!
    let host: String
    
    public init(to host: String, port: UInt16 = 80) throws {
        self.host = host
        self.client = try TCPClient(hostname: host, port: port) { pointer, count in
            self.responseProgress.parse(pointer, len: count)

            if self.responseProgress.complete, let response = self.responseProgress.makeResponse() {
                do {
                    try self.future.complete { response }
                } catch {
                    print("Future was already completed. Please don't manually complete futures.")
                }
                self.responseProgress.empty()
            }
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
