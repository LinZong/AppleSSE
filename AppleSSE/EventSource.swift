//
//  EventSource.swift
//  AppleSSE
//
//  Created by Nemesiss Lin on 2025/6/6.
//

import Foundation



enum EventSourceError: Error {
    case erronsousStatusCode(statusCode: Int)
    case invalidResponse
    case nestedError(error: Error?)
}

protocol EventSource {
    func request() -> URLRequest
    func cancel()
}

protocol EventSourceListener {
    func onOpen(response: URLResponse)
    func onEvent(id: String?, type: String?, data: String)
    func onClosed()
    func onFailure(error: EventSourceError?, response: URLResponse?)
}

class EventSources {
    static let shared = EventSources()
    
    private init() {
        
    }
    
    func newEventSource(_ req: URLRequest, _ listener: EventSourceListener) -> EventSource {
        var req = req
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let source = RealEventSource(req: req, listener: listener)
        source.connect()
        return source
    }
}

class RealEventSource: NSObject, URLSessionDataDelegate, EventSource {
    
    private let req: URLRequest
    private let listener: EventSourceListener
    private lazy var session: URLSession = { URLSession(configuration: .default, delegate: self, delegateQueue: nil) }()
    private var task: URLSessionDataTask? = nil
    private var reader = ServerSentEventReader()
    init(req: URLRequest, listener: EventSourceListener) {
        self.req = req
        self.listener = listener
    }
    
    func request() -> URLRequest {
        return self.req
    }
    
    func cancel() {
        self.task?.cancel()
        self.task = nil
    }
    
    func connect() {
        self.task = self.session.dataTask(with: self.req)
        self.task?.resume()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error = error {
            self.listener.onFailure(error: EventSourceError.nestedError(error: error), response: nil)
        }
        self.listener.onClosed()
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.reader.write(data)
        let events = self.reader.parseEvents()
        for event in events {
            self.listener.onEvent(id: event.id, type: event.type, data: event.data)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true else {
            self.listener.onFailure(error: EventSourceError.invalidResponse, response: response)
            self.listener.onClosed()
            return URLSession.ResponseDisposition.cancel
        }
        if httpResponse.statusCode == 200 {
            self.listener.onOpen(response: response)
            return URLSession.ResponseDisposition.allow
        } else {
            
            self.listener.onFailure(error: EventSourceError.erronsousStatusCode(statusCode: httpResponse.statusCode), response: response)
            self.listener.onClosed()
            return URLSession.ResponseDisposition.cancel
        }
    }
}
