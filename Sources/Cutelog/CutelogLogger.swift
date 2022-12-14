/*
    Copyright 2022 natinusala

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

import Dispatch
import Logging
import Socket
import Foundation
import SwiftMsgPack

private let internalCommandPrefix = "!!cutelog!!"

/// swift-log handler bound to a ``CutelogLogger``.
public struct CutelogHandler: LogHandler {
    let label: String
    let logger: CutelogLogger

    public var metadata = Logging.Logger.Metadata()
    public var logLevel: Logger.Level

    init(label: String, logLevel: Logger.Level, logger: CutelogLogger) {
        self.logger = logger
        self.label = label
        self.logLevel = logLevel
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        file: String,
        function: String,
        line: UInt
    ) {
        self.logger.log(
            label: self.label,
            level: level,
            message: message,
            metadata: metadata,
            file: file,
            function:
            function,
            line: line,
            date: Date()
        )
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set(newValue) {
            self.metadata[key] = newValue
        }
    }
}

/// Holds connection to a cutelog instance at a given address and port.
/// Use ``makeHandler(label:logLevel:)`` to make a swift-log handler.
public class CutelogLogger {
    enum State {
        case closed
        case opened(socket: Socket)
        case connected(socket: Socket)
        case running(socket: Socket)
        case crashed(reason: Error)

        var socket: Socket? {
            switch self {
                case .opened(let socket), .connected(let socket):
                    return socket
                default:
                    return nil
            }
        }
    }

    let address: String
    let port: Int32

    let queue: DispatchQueue
    let timer: DispatchSourceTimer

    // Everything below this point is queue-isolated

    let logger: Logger?

    /// Push at the end (using `append(_:)`)
    /// Pop at the start
    private var buffer: [LogRecord] = []

    var state: State {
        didSet {
            // Dynamically change the timer rate to avoid spamming connection attempts
            switch self.state {
                case .closed, .opened, .connected:
                    timer.schedule(deadline: .now(), repeating: connectInterval)
                case .running:
                    timer.schedule(deadline: .now(), repeating: workerInterval)
                case .crashed:
                    break
            }
        }
    }

    /// Creates a new Cutelog logger.
    public init(address: String, port: Int, internalLogger: Logger?, queue: DispatchQueue = DispatchQueue(label: "cutelog", qos: .background)) {
        self.address = address
        self.port = Int32(port)
        self.queue = queue
        self.logger = internalLogger
        self.state = .closed

        // Start the logger worker timer
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer

        timer.schedule(deadline: .now(), repeating: connectInterval)
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
    }

    deinit {
        self.timer.cancel()

        self.flush()

        self.state.socket?.close()
        self.state = .closed
    }

    private func tick() {
        switch self.state {
            case .closed:
                self.openSocket()
            case .opened(let socket):
                self.connect(socket: socket)
            case .connected(let socket):
                self.setup(socket: socket)
            case .running(let socket):
                self.dequeueRecords(to: socket)
            default:
                fatalError("Unimplemented \(self.state)")
        }
    }

    private func dequeueRecords(to socket: Socket) {
        var sent = 0

        do {
            for record in self.buffer.prefix(batchSize) {
                try self.send(record: record, to: socket)
                sent += 1
            }
        } catch {
            self.logger?.error("cutelog connection lost: \(error)")
            self.disconnect(socket: socket)
        }

        self.buffer = Array(self.buffer.dropFirst(sent))
    }

    /// Synchronously flushes the buffer to ensure that all pending logs are sent to cutelog.
    /// To be called when gracefully exiting your app or at the end of your tests.
    public func flush() {
        self.queue.sync {
            guard case .running(let socket) = self.state else {
                self.logger?.warning("Cannot flush cutelog as it is not connected - latest \(self.buffer.count) logs will be lost")
                return
            }

            self.logger?.info("Flushing cutelog, this might take a while...")

            for record in buffer {
                try? self.send(record: record, to: socket)
                Thread.sleep(forTimeInterval: 0.0001) // necessary to avoid crashing cutelog
            }

            self.buffer = []
        }
    }

    private func disconnect(socket: Socket) {
        socket.close()
        self.state = .closed
    }

    private func setup(socket: Socket) {
        do {
            try self.sendInternalCommand(.format, value: MessageFormat.messagePack.rawValue, to: socket)
            self.logger?.debug("Message format set to 'msgpack'")
        } catch {
            self.logger?.error("Cannot setup cutelog: \(error) - logs may not work or appear corrupted")
        }

        self.state = .running(socket: socket)
    }

    private func connect(socket: Socket) {
        do {
            try socket.connect(to: self.address, port: self.port, timeout: UInt(connectTimeout))

            self.state = .connected(socket: socket)
            self.logger?.info("Connected to cutelog on \(self.address):\(self.port)")
        } catch let error as Socket.Error {
            if error.errorCode == Socket.SOCKET_ERR_CONNECT_TIMEOUT {
                self.logger?.error("Cannot connect to cutelog on \(self.address):\(self.port) - connection timed out")
            } else {
                self.logger?.error("Cannot connect to cutelog on \(self.address):\(self.port) - \(error)")
            }
        } catch {
            self.logger?.error("Cannot connect to cutelog on \(self.address):\(self.port) - \(error)")
        }
    }

    private func openSocket() {
        do {
            let socket: Socket = try Socket.create(family: .inet, type: .stream, proto: .tcp)
            self.state = .opened(socket: socket)
        } catch {
            self.logger?.error("Cannot create socket: \(error)")
            self.state = .crashed(reason: error)
        }
    }

    private func sendInternalCommand(_ command: InternalCommand, value: String, to socket: Socket) throws {
        let payload = "\(internalCommandPrefix)\(command.rawValue)=\(value)"

        self.logger?.trace("Sending internal command '\(payload)'")

        guard let data = payload.data(using: .utf8) else {
            self.logger?.error("Cannot send internal command '\(payload)': cannot convert string to UTF8")
            return
        }

        try self.send(data: data, to: socket)
    }

    private func send(data: Data, to socket: Socket) throws {
        // Full payload is 4 bytes of size + content
        var len = UInt32(data.count).bigEndian
        let payload = Data(bytes: &len, count: MemoryLayout<UInt32>.size) + data

        try socket.write(from: payload)
    }

    private func send(record: LogRecord, to socket: Socket) throws {
        try self.send(data: record.data, to: socket)
    }

    func log(
        label: String,
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        file: String,
        function: String,
        line: UInt,
        date: Date
    ) {
        let record = LogRecord(
            label: label,
            message: message.description,
            level: level,
            created: date,
            file: file,
            line: line,
            function: function,
            metadata: metadata
        )

        self.queue.async {
            self.buffer.append(record)
        }
    }

    /// Creates a new `LogHandler` bound to this cutelog instance.
    public func makeHandler(label: String, logLevel: Logger.Level) -> CutelogHandler {
        return CutelogHandler(label: label, logLevel: logLevel, logger: self)
    }
}

extension Logger.Level {
    var cutelogLevel: String {
        return self.rawValue.uppercased()
    }
}
