//
//  ServerSentEventReader.swift
//  AppleSSE
//
//  Created by Nemesiss Lin on 2025/6/7.
//

import Foundation

struct Event {
    var id: String? = nil
    var type: String? = nil
    var data: String
}

class ServerSentEventReader {
    private var buffer = Data()
    private var lastEventId = ""
    private var event = ""
    private var data = ""
    
    func write(_ data: Data) {
        buffer.append(data)
    }
    
    func parseEvents() -> [Event] {
        var events: [Event] = []
        while !buffer.isEmpty {
            let start = 0
            guard let eol = findDataIndexForFirstEOL() else { return events }
            let end = eol.startIndex
            let lineRange = start ..< end
            let lineData = buffer[lineRange]
            buffer = buffer.advanced(by: lineRange.count + eol.count)
            guard let line = String(data: lineData, encoding: String.Encoding.utf8) else {continue}
            if line.isEmpty {
                let event = Event(id: lastEventId, type: event, data: data)
                events.append(event)
                cleanBufferedFields()
                continue
            }
            if line.starts(with: ":") {
                // If the line starts with a U+003A COLON character (:)
                // Ignore the line.
                continue
            }

            if line.contains(":") {
                var field = ""
                var value = ""
                // If the line contains a U+003A COLON character (:)
                // Collect the characters on the line before the first U+003A COLON character (:), and let field be that string.
                // Collect the characters on the line after the first U+003A COLON character (:), and let value be that string. If value starts with a U+0020 SPACE character, remove it from value.
                // Process the field using the steps described below, using field as the field name and value as the field value.

                let colonIndex = line.firstIndex(of: ":")!
                field = String(line[..<colonIndex])
                let valueIndex = line.index(after: colonIndex)
                value = String(line[valueIndex...])
                value.trimPrefix(" ")
                processField(field, value)
            }
        }

        return events
    }
    

    private func processField(_ field: String, _ value: String) {
        if field == "event" {
            // Set the event type buffer to the field value.
            event = value
            return
        }
        if field == "data" {
            // Append the field value to the data buffer, then append a single U+000A LINE FEED (LF) character to the data buffer.
            data += value
            data += "\n"
            return
        }
        if field == "id", !value.contains("\0") {
            // If the field value does not contain U+0000 NULL, then set the last event ID buffer to the field value. Otherwise, ignore the field.
            lastEventId = value
        }
    }
    
    private func cleanBufferedFields() {
        event = ""
        data = ""
        lastEventId = ""
    }
    
    private func findDataIndexForFirstEOL() -> Range<Data.Index>? {
        if let range = buffer.firstRange(of: Constants.CRLF) {
            return range
        }
        if let range = buffer.firstRange(of: Constants.LF) {
            return range
        }
        
        if let range = buffer.firstRange(of: Constants.CR) {
            return range
        }
        return nil
    }
    
    private class Constants {
        static let CRLF = "\r\n".data(using: String.Encoding.utf8)!
        static let CR = "\r".data(using: String.Encoding.utf8)!
        static let LF = "\n".data(using: String.Encoding.utf8)!
    }
}
