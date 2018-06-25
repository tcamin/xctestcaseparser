//
//  main.swift
//  TestListExtractor
//
//  Created by Tomas Camin on 12/12/2017.
//  Copyright © 2017 Tomas Camin. All rights reserved.
//

import Foundation
import Utility
import Basic

// The first argument is always the executable, drop it
let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())

let parser = ArgumentParser(usage: "[files] <options>", overview: "Extract tests from Swift files")

let extractProtocolArgument = parser.add(option: "--extract_protocols", kind: Bool.self, usage: "Return protocols that the containing class conforms to")
let excludeSourceFilesArguments = parser.add(option: "--exclude", shortName: "-x", kind: [String].self, usage: "Files to skip from parsing (wildcards accepted)")
let sourceFilesArguments = parser.add(positional: "files", kind: [String].self, usage: "Files to parse (wildcards accepted)")

var parsedArguments: ArgumentParser.Result?

do {
    parsedArguments = try parser.parse(arguments)
}
catch let error as ArgumentParserError {
    parser.printUsage(on: stdoutStream)
    print("\n" + error.description)

    exit(-1)
}
catch let error {
    parser.printUsage(on: stdoutStream)
    print("\n" + error.localizedDescription)
        
    exit(-1)
}

let synchQueue = DispatchQueue(label: "synchQueue")

let includeParameter = parsedArguments?.get(sourceFilesArguments)?.map { "-iname '\($0)'" }.joined(separator: " -o ") ?? ""
let excludeParameter = parsedArguments?.get(excludeSourceFilesArguments)?.map { "! -iname '\($0)'" }.joined(separator: " ") ?? ""
let extractProtocols = parsedArguments?.get(extractProtocolArgument) ?? false

let findInclude = "-type f \\( \(includeParameter) \\)"
let findExclude = excludeParameter.count > 0 ? "-type f \\( \(excludeParameter) \\)" : ""

var files = Set("find . \(findInclude) \(findExclude)".shellExecute().components(separatedBy: "\n"))

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
                if extractProtocols {
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
