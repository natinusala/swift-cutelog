# swift-cutelog

Standard swift-log handler for [cutelog](https://github.com/busimus/cutelog).

Allows displaying local logs in a GUI with searching and filtering features (similar to [NSLogger](https://github.com/fpillet/NSLogger)).

## Features
- pure Swift, works on all platforms where sockets are supported
- asynchronous, non-blocking logging
- automatically attempts to restore connection if lost
- supports metadata and namespaces (labels)
- suitable for tests with flushing and environment variables
- can send logs to multiple cutelog instances simultaneously

## Manual

### Install cutelog

1. Follow the instructions on the [cutelog README](https://github.com/busimus/cutelog#readme)
2. install the MessagePack serializer with `pip install msgpack`

### How to use

1. At the start of your app, create *one* `CutelogLogger` with the desired address and port
    - You can give it its own logger if you want, to report any networking errors or failures
    - You can also specify a custom `DispatchQueue`
2. Inside the `LoggingSystem.bootstrap` factory, call `makeHandler(label:logLevel:)` to get a `LogHandler` bound to this logger.

```swift
import Cutelog
import Logging

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
```

> **Warning**
> The `LoggingSystem.bootstrap` factory will be called EVERY TIME a new logger is created - DO NOT create the `CutelogLogger` in the factory, it will make a new connection for every new logger in your app.
> Instead, create the logger ONCE and then call `makeHandler(label:logLevel:)` in the factory to get a handler bound to this logger.

### How to use in a test environment

#### Enable logs for testing

To enable logs for testing you only need to bootstrap the logging system the same way that you do when running the app normally.

Since tests cannot have command line arguments, you can use environment variables instead to get the remote address and enable cutelog: `CUTELOG_ADDRESS=127.0.0.1 LOGLEVEL=trace swift test`.

Do this before calling `XCTestMain` and it should work out of the box.

#### Flushing logs

Since swift-cutelog is buffered and asynchronous, tests usually complete before swift-cutelog finishes sending all the logs over. This results in truncated logs when the tests end (because there is no graceful exit).

To solve this problem, the logger has a `flush()` method that will *synchronously* flush the buffer and send all remaining logs to cutelog (if connected). This usually takes some time and clogs up cutelog.

As `XCTestMain` never returns 🙃 you will need to make a dummy test case that runs at the end just to flush the logger.

### Nested namespaces

cutelog namespaces are mapped to swift-log logger labels.

You can use dots as a separator to make nested namespaces that show nicely in the cutelog sidebar: `let logger = Logger(label: "MyApp.Engine.Physics")`. That will show as `MyApp > Engine > Physics` inside cutelog.

### Metadata

Metadata is automatically sent to cutelog and will display in the bottom table when selecting a log entry.

You cannot have metadata with the following names as they are reserved:
- `name`
- `message`
- `levelname`
- `created`
- `file`
- `line`
- `function`

Conflicting metadata keys will be ignored.
