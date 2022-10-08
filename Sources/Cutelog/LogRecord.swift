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

import Foundation
import Logging

/// One log record sent to cutelog.
struct LogRecord {
    let label: String
    let message: String
    let level: Logger.Level
    let created: Date

    let file: String
    let line: UInt
    let function: String

    let metadata: Logger.Metadata?

    var data: Data {
        var values: [String: Any] = [
            "name": self.label,
            "message": self.message,
            "levelname": self.level.cutelogLevel,
            "created": Int(self.created.timeIntervalSince1970),
            "file": self.file,
            "line": self.line,
            "function": self.function,
        ]

        for (key, value) in self.metadata ?? [:] where values[key] == nil {
            values[key] = value.description
        }

        var data = Data()
        _ = try? data.pack(values)
        return data
    }
}
