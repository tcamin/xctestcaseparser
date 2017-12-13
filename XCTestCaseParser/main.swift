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
    print("usage: testlistextractor source_file[s] (wildcards accepted).\n\nNote: Only swift files are supported!")
    exit(-1)
}

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

for file in files {
    let parseOperation = ParseOperation(sourcePath: file)
    parseOperation.completionBlock = { [unowned parseOperation] in
        synchQueue.sync {
            for (k, v) in parseOperation.result {
                result.append(contentsOf: v.map { k + "/" + $0})
            }
        }
    }
    oq.addOperation(parseOperation)
}

oq.waitUntilAllOperationsAreFinished()

if let objectData = try? JSONSerialization.data(withJSONObject: result, options: JSONSerialization.WritingOptions(rawValue: 0)),
    let objectString = String(data: objectData, encoding: .utf8) {
    print(objectString)
}

exit(0)
