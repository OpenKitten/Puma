import XCTest
@testable import Puma

class PumaTests: XCTestCase {
    func testExample() throws {
        let client = try HTTPClient.sync(to: "example.com")
        
        let request = Request(method: .get, url: "/", headers: [
            "Host": "example.com"
            ])
        
        let response = try client.send(request)
        
        print(response)
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
