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

import Cutelog
import Logging
import Dispatch

// Create the logger, this will initiate the remote connection
let cutelogLogger = CutelogLogger(
    address: "127.0.0.1",
    port: Cutelog.defaultPort,
    internalLogger: nil // add one to display any networking errors or failures
)

// Will be called when a new `Logger` is created
LoggingSystem.bootstrap { label in
    return cutelogLogger.makeHandler(label: label, logLevel: .info)
}

// Then use swift-log normally

let logger = Logger(label: "Demo")

logger.info("Hello world!")

dispatchMain()
