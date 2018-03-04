# parser_wrapper

Swift CLI that given a directory of Swift source code files attempts to parse each file using [`swift-ast`](https://github.com/yanagiba/swift-ast) by yanagiba and then computes several metrics related to error handling. The computed metrics are then written to a .csv file. Each run of `parser_wrapper` generates one row for the output .csv file. 



`parser_wrapper` takes three arguments:

- **Key**: The key of the line that should be appended to the csv file. 
- **BaseDir**
- **OutFile**


