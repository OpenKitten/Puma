import XCTest
@testable import Puma

class PumaTests: XCTestCase {
    func testExample() throws {
        let request = Request(method: .get, path: "/", headers: [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13) AppleWebKit/604.1.28 (KHTML, like Gecko) Version/11.0 Safari/604.1.28"
        ])
        
        let response = try SyncHTTPClient.send(request, to: "https://independer.nl/")
        
        print(response)
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
