# CoreDataSupport

<a href="LICENSE">
<img src="https://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
</a>
<a href="https://swift.org">
<img src="https://img.shields.io/badge/swift-5.2-brightgreen.svg" alt="Swift 5.2">
</a>
<a href="https://github.com/stairtree/CoreDataSupport/actions">
<img src="https://github.com/stairtree/CoreDataSupport/workflows/test/badge.svg" alt="CI">
</a>


Common helpers and idioms for making working with Core Data in Swift better. 

### Supported Platforms

CoreDataSupport is tested on macOS, iOS, tvOS, and is known to support the following operating system versions:

* macOS 10.14+
* iOS 11+
* tvOS 11+
* watchOS (untested since watchOS doesn't support `XCTest`)

To integrate the package:

```swift
dependencies: [
.package(url: "https://github.com/stairtree/CoreDataSupport.git", .branch("main"))
]
```

_**Note**: No releases have yet been tagged._

---

Inspired and contains code from the excellent [objc.io book](https://www.objc.io/books/core-data/) by Florian Kugler and Daniel Eggert (See `LICENSE.objc.io.txt`).
