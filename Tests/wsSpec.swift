//
// Created by Jason Flax on 3/3/16.
//

import Foundation
@testable import seraph
import XCTest

class TestWsController: WsController {
    override init() {
        super.init()

        self.register(
                +"/ws",
                handler: {
                    req in
                    let response = [
                            "success": true,
                    ]

                    return WsMessage(response: response)
                },
                contentType: ContentType.ApplicationJson,
                verbs: HttpVerb.GET
        )
    }
}

class WsControllerTests: XCTestCase {
    let testController = TestWsController()

    func test_WsIoManager() {
        let manager = TestWsIoManager(host: "192.168.0.182", port: 8888)
        manager.loop()
    }
}
