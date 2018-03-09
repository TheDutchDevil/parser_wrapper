# parser_wrapper

Swift CLI that given a directory of Swift source code files attempts to parse each file using [`swift-ast`](https://github.com/yanagiba/swift-ast) by yanagiba and then computes several metrics related to error handling. The computed metrics are then written to a .csv file. Each run of `parser_wrapper` generates one row for the output .csv file. This CLI has been used as part of the paper 'How do Swift developers handle errors'. 

To re-run the experiments, and execute the full pipeline, see the following [Gist](https://gist.github.com/TheDutchDevil/31d2b54420ffab0d798a26c0b8fe2516). In the Gist the steps needed to run this tool and all other scripts used to gather the final results are described in detail. 

`parser_wrapper` itself takes three arguments:

- **Key**: The key of the line that should be appended to the csv file. 
- **BaseDir**: Directory which is the starting point for recursively finding Swift source files. ALl files that end in .swift are parsed using `parser_wrapper` and the error handling in these files is recorded. After all swift files in the directory have been parsed all results are written to **OutFile**.
- **OutFile**: The .csv to which results should be appended after parsing all Swift files in a directory tree. Note that before calling `parser_wrapper` this file should exist on the file system with a header. The following csv header should be used: 
    
    `key, parsedFiles, parserFailed, parserFailedNoEh, compilerFailed, errorTypesEnum, errorTypesClass, errorTypesStruct, throwStatements, try, tryOpt, tryForce, doStatements, throwMethods, rethrows, catch, catchEnum, catchAll, emptyCatch, emptyCatchEnum, emptyCatchAll, catchPerDoMedian, catchPerDoAverage, slocPerCatchMedian, slocPerCatchAverage, slocPerCatchEnumMedian, slocPerCatchEnumAverage, slocPerCatchAllMedian, slocPerCatchAllAverage`
    
    What each of the collected metrics means and why these metrics have been chosen is described in the paper.
    
## Build instructions

Building parser_wrapper includes downloading all dependencies such that `parser_wrapper` can be linked against the dependencies. This is handled by the Swift build system itself. Building `parser_wrapper` can be done by opening a terminal in the root folder of the repository and running `swift build`. Build artifacts can be found in the `.debug` folder.

`Package.swift `is the file which contains the information needed by the build system of Swift. Currently the dependency on `swift-ast` points to a [fork](https://github.com/TheDutchDevil/swift-ast) of the original `swift-ast` repository by yanagiba. This to prevent any breaking API changes from influencing `parser_wrapper`. It should always be possible to point back to the original version of `swift-ast` in case bugs in the original repository are fixed.




