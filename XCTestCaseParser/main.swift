//
//  main.swift
//  TestListExtractor
//
//  Created by Tomas Camin on 12/12/2017.
//  Copyright © 2017 Tomas Camin. All rights reserved.
//

import Foundation

let synchQueue = DispatchQueue(label: "synchQueue")

let arguments = CommandLine.arguments.dropFirst()

if arguments.count == 0 {
    print("usage: testlistextractor [OPTIONS] source_file[s] (wildcards accepted).\n\nNote: Only swift files are supported!")
    print("\t--extract_protocols\treturn protocols that the containing class confirms to")
    exit(-1)
}
let extract_protocols = (arguments.first == "--extract_protocols")

let skipItems = Set([".", "..", ""])

var files = Set<String>()
// arguments should either be filenames or bash wildcards
for argument in arguments {
    var partialFiles = Set("find . -name '\(argument)'".shellExecute().components(separatedBy: "\n"))
    
    partialFiles = partialFiles.subtracting(skipItems)
    files = files.union(partialFiles)
}

files = files.filter { $0.hasSuffix(".swift") }

let oq = OperationQueue()
oq.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount

var result = [String]()

var semaphores = [DispatchSemaphore]()
for file in files {
    let parseOperation = ParseOperation(sourcePath: file)
    
    let sem = DispatchSemaphore(value: 0)
    semaphores.append(sem)
    parseOperation.completionBlock = { [unowned parseOperation] in
        synchQueue.sync {
            for (k, v) in parseOperation.result {
                if extract_protocols {
                    v.forEach { assert($0.conformedProtocols.count > 0, "Failed to get conformedProtocols") }
                    let testMethods = v.map { k + "/" + $0.methodName + "|" + $0.conformedProtocols.joined(separator: ",") }
                    result.append(contentsOf: testMethods)
                } else {
                    let testMethods = v.map { k + "/" + $0.methodName }
                    result.append(contentsOf: testMethods)
                }
            }
        }
        sem.signal()
    }
    oq.addOperation(parseOperation)
}

oq.waitUntilAllOperationsAreFinished()
for semaphore in semaphores {
    semaphore.wait()
}

if let objectData = try? JSONSerialization.data(withJSONObject: result, options: JSONSerialization.WritingOptions(rawValue: 0)),
    let objectString = String(data: objectData, encoding: .utf8) {
    print(objectString)
}

exit(0)
