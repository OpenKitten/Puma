import XCTest
@testable import Puma

class PumaTests: XCTestCase {
    func testExample() throws {
        let request = Request(method: .get, path: "/")
        
        let response = try SyncHTTPClient.send(request, toHost: "google.com", securely: true)
        
        print(response)
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
