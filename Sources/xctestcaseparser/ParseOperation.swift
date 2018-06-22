//
//  ParseOperation.swift
//  TestListExtractor
//
//  Created by Tomas Camin on 12/12/2017.
//  Copyright © 2017 Tomas Camin. All rights reserved.
//

import Cocoa

class ParseOperation: Operation {
    private let sourcePath: String
    var result = [String : Set<ParsingItem>]()

    init(sourcePath: String) {
        self.sourcePath = sourcePath
    }
    
    override func main() {
        guard !isCancelled else {
            return
        }
                
        var ast = "swiftc -print-ast \(sourcePath) 2> /dev/null".shellExecute()
        ast = ast.replacingOccurrences(of: "final ", with: "")
        ast = ast.replacingOccurrences(of: "private ", with: "")
        ast = ast.replacingOccurrences(of: "public ", with: "")
        ast = ast.replacingOccurrences(of: "internal ", with: "")
        ast = ast.replacingOccurrences(of: "extension ", with: "class ")
        ast = ast.replacingOccurrences(of: ":", with: " : ")
        while ast.contains("  ") {
            ast = ast.replacingOccurrences(of: "  ", with: " ")
        }
        ast = ast.replacingOccurrences(of: " func ", with: "func ")
        
        let astLines = ast.components(separatedBy: "\n")
        
        // make sure it's a test case
        if !ast.replacingOccurrences(of: " ", with: "").contains(":XCTestCase{") {
            return
        }
        
        let classMark = "class "
        let funcMark = "func "
        
        var currentClassName: String?
        var currentProtocols: [String] = []
        var currentSet = Set<ParsingItem>()
        for line in astLines {
            if line.hasPrefix(classMark), currentClassName == nil {
                currentClassName = String(line.dropFirst(classMark.count))
                currentProtocols = currentClassName?.components(separatedBy: ", ").dropFirst().map { $0.components(separatedBy: " ").first ?? "" } ?? []
                currentClassName = currentClassName?.components(separatedBy: " ").first
                
                currentSet = result[currentClassName ?? ""] ?? Set()
                
                continue
            }
            
            guard currentClassName != nil else {
                continue
            }
            
            if line.hasPrefix("\(funcMark)test") && line.contains("()") {
                var testMethodName = String(line.dropFirst(funcMark.count))
                testMethodName = testMethodName.replacingOccurrences(of: "()", with: "")
                
                let parsingItem = ParsingItem(methodName: testMethodName, conformedProtocols: currentProtocols)
                
                currentSet.insert(parsingItem)
            } else if line == "}" {
                if currentSet.count > 0 {
                    result[currentClassName!] = currentSet
                }
                currentClassName = nil
            }
        }
    }
}

class ParsingItem: Hashable {
    let methodName: String
    let conformedProtocols: [String]
    
    var hashValue: Int {
        return methodName.hashValue
    }
    
    static func ==(lhs: ParsingItem, rhs: ParsingItem) -> Bool {
        return lhs.methodName == rhs.methodName
    }
    
    init(methodName: String, conformedProtocols: [String]) {
        self.methodName = methodName
        self.conformedProtocols = conformedProtocols
    }
}
