# xctestcaseparser
A simple utility to extract the list of tests in swift XCTestCases.

This can be particularly useful when splitting UI Tests in parallel.

# Usage

Call the script by passing one or more .swift source files to be parsed (wildcards accepted)

`xctestcaseparser source_file…` 

This will return a JSON array with the list of tests