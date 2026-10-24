import Foundation

enum AppLocalization {
    static let translations:[String:String] = {
        guard let url=Bundle.main.url(forResource:"Translations",withExtension:"json"),let bytes=try? Data(contentsOf:url),let table=try? JSONDecoder().decode([String:String].self,from:bytes) else {return [:]}
        return table
    }()
    static func translate(_ text:String,language:String,table:[String:String]=translations)->String {
        guard language != "de" else {return text}
        if let value=table[text] {return value}
        for key in table.keys.filter({$0.contains("%@")}).sorted() {
            let pattern="^"+key.components(separatedBy:"%@").map{NSRegularExpression.escapedPattern(for:$0)}.joined(separator:"(.*?)")+"$"
            guard let regex=try? NSRegularExpression(pattern:pattern,options:[.dotMatchesLineSeparators]),let match=regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)) else {continue}
            var translated=table[key] ?? text
            for index in 1..<match.numberOfRanges {
                guard let range=Range(match.range(at:index),in:text),let placeholder=translated.range(of:"%@") else {continue}
                translated.replaceSubrange(placeholder,with:String(text[range]))
            }
            return translated
        }
        return text
    }
}
func L(_ text:String)->String {AppLocalization.translate(text,language:UserDefaults.standard.string(forKey:"language") ?? "en")}
