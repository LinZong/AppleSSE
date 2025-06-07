//
//  main.swift
//  AppleSSE
//
//  Created by Nemesiss Lin on 2025/6/5.
//

import Foundation


let condition = NSCondition()

extension Date {
    var millisecondsSince1970: Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

class SSEListener: EventSourceListener {
    func onOpen(response: URLResponse) {
        print("onOpen, response: \(response)")
    }
    
    func onEvent(id: String?, type: String?, data: String) {
        let clientTime = Date().millisecondsSince1970
        print("onEvent -- id: \(id), type: \(type), data: \(data), clientTime: \(clientTime)")
    }
    
    func onClosed() {
        print("onClose")
        condition.signal()
    }
    
    func onFailure(error: EventSourceError?, response: URLResponse?) {
        print("onFailure. error: \(error), response: \(response)")
    }
}

let request = URLRequest(url: URL(string: "http://y430p.io:8000/sse")!)
let source = EventSources.shared.newEventSource(request, SSEListener())
condition.wait()
