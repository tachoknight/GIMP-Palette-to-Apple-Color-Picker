//
//  main.swift
//  GIMP Palette to Color Picker
//
//  Created by Ron Olson on 9/11/21.
//

import Cocoa
import Foundation

//
// This program creates Apple .clr files from GIMP Palette files.
//

struct Color: Hashable {
    var name = ""
    var red = 0
    var green = 0
    var blue = 0

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(self.red))
        hasher.combine(String(self.green))
        hasher.combine(String(self.blue))
    }

    func getNSColor() -> NSColor {
        func roundTo3(_ val: Int16) -> Float {
            let x = Float(val) / 255.0
            let y = Double(round(1000 * x) / 1000)
            return Float(y)
        }
        return NSColor(red: CGFloat(roundTo3(Int16(self.red))), green: CGFloat(roundTo3(Int16(self.green))), blue: CGFloat(roundTo3(Int16(self.blue))), alpha: CGFloat(1.0))
    }
}

// Needed for the duplicate removal part
func ==(lhs: Color, rhs: Color) -> Bool {
    return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue
}

/*******************************************************************************************
 *      E X T E N S I O N S
 *******************************************************************************************/

extension String {
    // 'Cause come on, it's always gonna be this and that's a lot of typing...
    func length() -> Int {
        return lengthOfBytes(using: String.Encoding.utf8)
    }
}

// For parsing the file
extension String {
    var lines: [String] {
        return self.components(separatedBy: "\n")
    }
}

// Get a specific character from a string
extension String {
    func characterAtIndex(index: Int) -> Character? {
        var cur = 0
        for char in self {
            if cur == index {
                return char
            }
            cur += 1
        }
        return nil
    }
}

extension String {
    subscript(bounds: CountableClosedRange<Int>) -> String {
        let lowerBound = max(0, bounds.lowerBound)
        guard lowerBound < self.count else { return "" }

        let upperBound = min(bounds.upperBound, self.count-1)
        guard upperBound >= 0 else { return "" }

        let i = index(startIndex, offsetBy: lowerBound)
        let j = index(i, offsetBy: upperBound-lowerBound)

        return String(self[i ... j])
    }

    subscript(bounds: CountableRange<Int>) -> String {
        let lowerBound = max(0, bounds.lowerBound)
        guard lowerBound < self.count else { return "" }

        let upperBound = min(bounds.upperBound, self.count)
        guard upperBound >= 0 else { return "" }

        let i = index(startIndex, offsetBy: lowerBound)
        let j = index(i, offsetBy: upperBound-lowerBound)

        return String(self[i..<j])
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}

public extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return self.filter { seen.insert($0).inserted }
    }
}

// This function returns a list of all the files for a particular subdirectory
// under one of the base directories that is accessible via a FileManager.SearchPathDirectory
// which a UInt because of sandboxing limiting access to certain locations (in other words,
// arbitrary paths are a no-no).
func listAllFileNamesExtension(for baseDirectory: FileManager.SearchPathDirectory, nameDirectory: String, extensionWanted: String) -> (names: [String], paths: [URL]) {
    let documentURL = FileManager.default.urls(for: baseDirectory, in: .userDomainMask).first!
    let Path = documentURL.appendingPathComponent(nameDirectory).absoluteURL

    do {
        try FileManager.default.createDirectory(atPath: Path.relativePath, withIntermediateDirectories: true)
        // Get the directory contents urls (including subfolders urls)
        let directoryContents = try FileManager.default.contentsOfDirectory(at: Path, includingPropertiesForKeys: nil, options: [])

        // if you want to filter the directory contents you can do like this:
        let FilesPath = directoryContents.filter { $0.pathExtension == extensionWanted }
        let FileNames = FilesPath.map { $0.deletingPathExtension().lastPathComponent }

        return (names: FileNames, paths: FilesPath)

    } catch {
        print(error.localizedDescription)
    }

    return (names: [], paths: [])
}

func loadFile(_ file: URL) -> String {
    var contents = ""
    do {
        contents = try String(contentsOf: file)
    } catch {
        print("Failed reading from URL: \(file), Error: " + error.localizedDescription)
    }

    return contents
}

// Return a dictionary that contains the name of the palette as the
// key, and an array of colors
func parseFileContents(_ fileContents: String) -> [String: [Color]] {
    var colorDict = [String: [Color]]()
    var colors = [Color]()
    var paletteName = ""

    for line in fileContents.lines {
        if line.length() == 0 {
            continue
        }

        if line.contains("Name:") {
            let parts = line.components(separatedBy: "Name:")
            paletteName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        }

        // Only work with the line if the first character is a number, because
        // in this file format that's what denotes a row of RGB values
        if line.characterAtIndex(index: 0)!.isNumber {
            var color = Color()
            let lineParts = line.components(separatedBy: "\t")

            // There may be spaces when the number is not three digits, so
            // we take care of that before converting to Integers
            color.red = Int(lineParts[0].trimmingCharacters(in: .whitespacesAndNewlines))!
            color.green = Int(lineParts[1].trimmingCharacters(in: .whitespacesAndNewlines))!
            color.blue = Int(lineParts[2].trimmingCharacters(in: .whitespacesAndNewlines))!
            // And the name
            color.name = lineParts[3].trimmingCharacters(in: .whitespacesAndNewlines)

            colors.append(color)
        }
    }

    // And remove dupes based on RGB balues
    print("Colors array before: \(colors.count)")
    // colors.removeDuplicates()
    colors = colors.uniqued()
    print("Colors array after: \(colors.count)")
    colors = colors.sorted { $0.name.lowercased() < $1.name.lowercased() }

    colorDict[paletteName] = colors

    return colorDict
}

/*******************************************************************************************
 *      P R O G R A M  S T A R T
 *******************************************************************************************/

let allGIMPPaletteFiles = listAllFileNamesExtension(for: .downloadsDirectory, nameDirectory: "Embroidery Color Palettes", extensionWanted: "gpl")

// print(allJsonNamePath.paths[4])
// print(loadFile(allJsonNamePath.paths[4]))
allGIMPPaletteFiles.paths.forEach { file in
    let colors = parseFileContents(loadFile(file))

    // There's only one key/value pair in the dictionary, but regardless we
    // use the standard for() loop to get at them easily
    for (key, value) in colors {
        let newFilename = key.replacingOccurrences(of: "/", with: "_")
        let colorList = NSColorList(name: newFilename)
        for color in value {
            colorList.setColor(color.getNSColor(), forKey: color.name)
        }

        // And write the file, which will go directly to
        // /Users/<user>/Library/Colors/newFilename.clr
        do {
             try colorList.write(to: URL(string: String(format: "file:///%s.clr", newFilename)))
        } catch {
            print("Hmm, when writing got \(error)")
        }
    }
}

print("Hello, World!")
