import AST
import Parser
import Source 
import Diagnostic

import Foundation

CommandLine.arguments.remove(at: 0)

var whichPaths = [String : String]()

class TryCatchCounter : ASTVisitor {

  var regular: Int = 0 // try
  var forceClose: Int = 0// try!
  var tryNill: Int = 0 // try?
  
  var throwMethods: Int = 0
  var rethrowMethods: Int = 0
  
  var throwStatements: Int = 0
  
  var doStatements: Int = 0
  
  var catchEnumClauses = 0
  var catchClauses = 0
  var catchAll = 0
  
  var emptyCatch = 0
  var emptyCatchEnum = 0
  var emptyCatchAll = 0
  
  var catchPerDo = [Int]()
  
  var slocPerCatch = [Int]()
  var slocPerCatchEnum = [Int]()
  var slocPerCatchAll = [Int]()
  
  var inheritPairsEnum = [(base:String, parent:String)]()
  var inheritPairsClass = [(base: String, parent:String)]()
  var inheritPairsStruct = [(base: String, parent:String)]()
  
  func visit(_ expr : TryOperatorExpression) throws -> Bool {  
	
	switch expr.kind {
		case .try:
			self.regular += 1
		case .forced:
			self.forceClose += 1
		case .optional:
			self.tryNill += 1
	}
	
	return true
  }
  
  func visit(_ decl : ClassDeclaration) throws -> Bool {
	if decl.typeInheritanceClause != nil {
		for typeId in decl.typeInheritanceClause!.typeInheritanceList {			
			inheritPairsClass.append((base: decl.name.textDescription, parent: typeId.names.last!.name.textDescription))
		}
	}
	
	return true
  }
  
  func visit(_ decl : EnumDeclaration) throws -> Bool {
	if decl.typeInheritanceClause != nil {
		for typeId in decl.typeInheritanceClause!.typeInheritanceList {
			inheritPairsEnum.append((base: decl.name.textDescription, parent: typeId.names.last!.name.textDescription))
		}
	}
	
	return true
  }
  
  func visit(_ decl : StructDeclaration) throws -> Bool {
	if decl.typeInheritanceClause != nil {
		for typeId in decl.typeInheritanceClause!.typeInheritanceList {
			inheritPairsStruct.append((base: decl.name.textDescription, parent: typeId.names.last!.name.textDescription))
		}
	}
	
	return true
  }
  
  func visit(_ stmt : ThrowStatement) throws -> Bool {
	throwStatements += 1
	
	return true
  }
  
  func visit(_ decl : FunctionDeclaration) -> Bool {
      
	  switch decl.signature.throwsKind {
		case .throwing:
			self.throwMethods += 1
		case .rethrowing:
			self.rethrowMethods += 1
		default:
			()
	  }
	  
	  return true
  }
  
  func visit(_ stmt : DoStatement) -> Bool {
	
	catchPerDo.append(stmt.catchClauses.count)
	
	doStatements += 1
	
	for clause in stmt.catchClauses {
	
		let clocRes = execCommand(command: "cloc", args: ["--stdin-name=hw.swift", "--csv", "--quiet", "--force-lang=swift", "-"], fileInput: clause.codeBlock.statements.textDescription, workingDir: nil)
		
		
		let catchCloc = Int(clocRes.output.components(separatedBy: "1,Swift,")[1].components(separatedBy: ",")[2].trimmingCharacters(in: .whitespacesAndNewlines))!
		
		var isCatchAll = false
		var isCatchEnum = false
	
		if clause.pattern == nil {
			isCatchAll = true
		} else if clause.pattern is EnumCasePattern {
			isCatchEnum = true
		} else if clause.pattern is ValueBindingPattern {
			isCatchAll = true
		} else if clause.pattern is TypeCastingPattern {
			let typeCast = clause.pattern as! TypeCastingPattern
			
			var type : Type
			
			switch typeCast.kind {
				case .as(_, let cast):
					type = cast
				case .is(let cast):
					type = cast
			}
			
			switch type {
			case let identifier as TypeIdentifier:
				if identifier.names.first!.name.textDescription == "Error" || 
					identifier.names.first!.name.textDescription == "NSError" {
					isCatchAll = true
				}
			default:
				()
				}
		}
		
		if isCatchAll {
			catchAll += 1
			
			slocPerCatchAll.append(catchCloc)
			
			if clause.codeBlock.statements.count == 0 {
				emptyCatchAll += 1
			}
		} 
		else if isCatchEnum {
			catchEnumClauses += 1
			
			slocPerCatchEnum.append(catchCloc)
			
			if clause.codeBlock.statements.count == 0 {
				emptyCatchEnum += 1
			}
		}
		else 
		{
			slocPerCatch.append(catchCloc)
		
			catchClauses += 1
		
			if clause.codeBlock.statements.count == 0 {
				emptyCatch += 1
			}
		 }
		
	}
	
	return true
  }
}

func findTypesThatInheritFromError(types: [(base:String, parent:String)]) -> [String] {

	var res = ["Error"]
	var foundThisIter = 0
	
	repeat {
		foundThisIter = 0
		
		for pair in types {
			if res.contains(pair.parent) && !res.contains(pair.base) {
				res.append(pair.base)
				foundThisIter += 1
			}
		}
		
	} while foundThisIter > 0
	
	res.remove(at: 0)
	
	return res
}

func execCommand(command: String, args: [String], fileInput: String?, workingDir: String?, readStdOut: Bool = true) -> (code: Int32, output: String, errorOutput: String) {
    if !command.hasPrefix("/") , let fullCommand = whichPaths[command] {
		return execCommand(command: fullCommand, args: args, fileInput: fileInput, workingDir: workingDir)
	} else if !command.hasPrefix("/") {
        let commandFull = execCommand(command: "/usr/bin/which", args: [command], fileInput: nil, workingDir: nil).output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
		
		whichPaths[command] = commandFull
		
        return execCommand(command: commandFull, args: args, fileInput: fileInput, workingDir: workingDir)
    } else {	
        let proc = Process()
        proc.launchPath = command
		
		if workingDir != nil {
			proc.currentDirectoryPath = workingDir!
		}
		
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
		
		let errPipe = Pipe()
		proc.standardError = errPipe
		
		
		let writePipe = Pipe()
		
		if fileInput != nil {
			
			let fileInputWithNewLine = fileInput! + "\n"
			
			writePipe.fileHandleForWriting.write(fileInputWithNewLine.data(using: .utf8)!)	
		
			writePipe.fileHandleForWriting.closeFile()
			proc.standardInput = writePipe
		}
		
        proc.launch()
		
		var stdOut = ""
		
		if readStdOut {
		
			let data = pipe.fileHandleForReading.readDataToEndOfFile()
			
			stdOut = String(data: data, encoding: String.Encoding.utf8)!
		
		}
		
		let errorData = errPipe.fileHandleForReading.readDataToEndOfFile()
				
        return (proc.terminationStatus, stdOut, String(data: errorData, encoding: String.Encoding.utf8)!)
    }
}

func calculateMedian(array: [Int]) -> Float {

	if array.count == 0 {
		return 0
	}

    let sorted = array.sorted()
    if sorted.count % 2 == 0 {
        return Float((sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1])) / 2
    } else {
        return Float(sorted[(sorted.count - 1) / 2])
    }
}

extension Array where Element: Numeric {
    /// Returns the total sum of all elements in the array
    var total: Element { return reduce(0, +) }
}

extension Array where Element: BinaryInteger {
    /// Returns the average of all elements in the array
    var average: Double {
        return isEmpty ? 0 : Double(Int(total)) / Double(count)
    }
}

extension Array where Element: FloatingPoint {
    /// Returns the average of all elements in the array
    var average: Element {
        return isEmpty ? 0 : total / Element(count)
    }
}

let dateFormatter = DateFormatter()

 func stringToDate(dateString: String, timeZone: TimeZone = TimeZone.current) -> Date {
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = timeZone
    return dateFormatter.date(from: dateString) ?? Date()
} 

let key = CommandLine.arguments.first!
CommandLine.arguments.remove(at: 0)
let baseDir = CommandLine.arguments.first!
CommandLine.arguments.remove(at: 0)
let outFile = CommandLine.arguments.first!

//Iterates over all files in a directory
let filemanager:FileManager = FileManager()
let files = filemanager.enumerator(atPath: baseDir)

var swiftFiles = [String]()

var failedParse = 0
var failedParseNoEh = 0
var failedCompiler = 0
var parsed = 0

while let file = files?.nextObject() {
    if (file as! String).hasSuffix(".swift") {
	  swiftFiles.append(baseDir + "/" + (file as! String))
	}
}



	
let visitor = TryCatchCounter()

print("Processing key: \(key)")
	
for swiftFile in swiftFiles {

	let name = URL(fileURLWithPath: swiftFile).lastPathComponent
	
	//Exception is needed for these files, as they don't compile with the Swift 4 compiler
	//and for some reason reading the standard output of calling the swift 4 compiler on
	//the files hangs and never returns.
	if swiftFile.range(of: "Curry/Source/Curry.swift") != nil ||
		swiftFile.range(of: "Section 1 - First Class Types.xcplaygroundpage/Contents.swift") != nil ||
		swiftFile.range(of: "Section 2 - Function Composition.xcplaygroundpage/Contents.swift") != nil ||
		swiftFile.range(of: "/Tribute/TributeTests/TributeTests.swift") != nil ||
		swiftFile.range(of: "cocoa-programming-for-osx-5e/Chapter 33 - CoreAnimation/Scattered/Scattered/ViewController.swift") != nil ||
		swiftFile.range(of: "cocoa-programming-for-osx-5e/Chapter 34 - Concurrency/Scattered/Scattered/ViewController.swift") != nil ||
		swiftFile.range(of: "Exis/CardsAgainstHumanityDemo/swiftCardsAgainst/Pods/Riffle/Pod/Classes/GenericWrappers.swift") != nil	||
		swiftFile.range(of: "objc/util/util/SQLite/Expression.swift") != nil 		{
			failedCompiler += 1
			continue
	}
	
	if swiftFile.range(of: "cocoa-programming-for-osx-5e/Chapter 01 - GetStarted/RandomPassword/RandomPassword/GeneratePassword.swift") != nil ||
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxCocoa/RxCocoa/Common/CocoaUnits/Driver/Driver.swift") != nil ||
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxCocoa/RxCocoa/Common/DelegateProxyType.swift") != nil ||
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxSwift/RxSwift/Disposables/Disposables.swift") != nil ||
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxSwift/RxSwift/Observables/Implementations/Skip.swift") != nil || 
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxSwift/RxSwift/Observables/Observable+Creation.swift") != nil || 
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxSwift/RxSwift/Platform/Platform.Linux.swift") != nil ||
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/PokedexGo/Pokemon.swift") != nil {
		failedParseNoEh += 1
		continue
	}

	if swiftFile.range(of: "cocoa-programming-for-osx-5e/Chapter 28 - WebServices/RanchForecast/RanchForecast/ScheduleFetcher.swift") != nil ||
		swiftFile.range(of: "cocoa-programming-for-osx-5e/Chapter 29 - UnitTest/RanchForecast/RanchForecast/ScheduleFetcher.swift") != nil ||
			swiftFile.range(of: "cocoa-programming-for-osx-5e/Chapter 32 - Storyboards/RanchForecastSplit/RanchForecastSplit/ScheduleFetcher.swift") != nil ||
		swiftFile.range(of: "cocoa-programming-for-osx-5e/Chapter 36 - Distribution/RanchForecastSplit/RanchForecastSplit/ScheduleFetcher.swift") != nil ||
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxSwift/RxSwift/Concurrency/Lock.swift") != nil ||
		swiftFile.range(of: "Swift30Projects/Project 07 - PokedexGo/Pods/RxSwift/RxSwift/Observables/Observable+Single.swift") != nil		{
		failedParse += 1
		continue
	}
	
	if name.hasPrefix("._") || (swiftFile.range(of: "34892908") != nil && name.hasPrefix("__")){
		continue
	}
	
	print("Starting with \(swiftFile)")

	do {	
		let sourceFile = try SourceReader.read(at: swiftFile)
		let parser = Parser(source: sourceFile)
		let topLevelDecl = try parser.parse()
		
		let _ = try! visitor.traverse(topLevelDecl)
		
		parsed += 1

	} catch _ {
		let compResult = execCommand(command: "swiftc", args: ["-parse", "-parseable-output", "\(swiftFile)"], fileInput: nil, workingDir: nil, readStdOut: false)
		
		if compResult.errorOutput.range(of: "\"exit-status\": 1") != nil {
			failedCompiler += 1
			print("Compiler failed to parse \(swiftFile)")
		} else {
		
			let grepResult = execCommand(command: "grep", args: ["-c", "-E", "(do[[:space:]]*{)|(try\\!)|(try\\?)", "\(swiftFile)"], fileInput: nil, workingDir: nil)
			
			let lines = Int(grepResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
		
			if lines != nil && lines! > 0 {		
				failedParse += 1		
				print("Parser failed to parse \(swiftFile)")			
			} else if lines != nil && lines! == 0 {
				failedParseNoEh += 1
				print("Parser failed to parse a file without EH code \(swiftFile)")					
			} else {
				failedParse += 1		
				print("Parser failed to parse and grep failed (\(grepResult.output.trimmingCharacters(in: .whitespacesAndNewlines))) \(swiftFile)")	
			}
		}		
	}
}

let errTypesEnum = findTypesThatInheritFromError(types: visitor.inheritPairsEnum)
let errTypesClass = findTypesThatInheritFromError(types: visitor.inheritPairsClass)
let errTypesStruct = findTypesThatInheritFromError(types: visitor.inheritPairsStruct)

do {
        let fileHandle = try FileHandle(forWritingTo: Foundation.URL(string: outFile)!)
            fileHandle.seekToEndOfFile()
            fileHandle.write("\(key), \(parsed), \(failedParse), \(failedParseNoEh), \(failedCompiler), \(errTypesEnum.count), \(errTypesClass.count), \(errTypesStruct.count), \(visitor.throwStatements), \(visitor.regular), \(visitor.tryNill), \(visitor.forceClose), \(visitor.doStatements), \(visitor.throwMethods), \(visitor.rethrowMethods), \(visitor.catchClauses), \(visitor.catchEnumClauses), \(visitor.catchAll), \(visitor.emptyCatch), \(visitor.emptyCatchEnum), \(visitor.emptyCatchAll), \(calculateMedian(array: visitor.catchPerDo)), \(visitor.catchPerDo.average), \(calculateMedian(array: visitor.slocPerCatch)), \(visitor.slocPerCatch.average), \(calculateMedian(array: visitor.slocPerCatchEnum)), \(visitor.slocPerCatchEnum.average), \(calculateMedian(array: visitor.slocPerCatchAll)), \(visitor.slocPerCatchAll.average)\n".data(using: .utf8)!)
            fileHandle.closeFile()
    } catch {
        print("Error writing to file \(error)")
    }


