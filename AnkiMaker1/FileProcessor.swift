import Foundation
import SwiftUI

class FileProcessor: ObservableObject {
    @Published var notes: [Note] = []
    @Published var errorMessage: String?
    
    func processFile(at url: URL) {
        print("开始处理文件: \(url)")
        
        do {
            // 尝试读取文件内容
            let content = try String(contentsOf: url, encoding: .utf8)
            print("成功读取文件内容，长度: \(content.count) 字符")
            print("文件内容预览: \(content.prefix(100))")
            
            let notes = parseContent(content)
            
            DispatchQueue.main.async {
                self.notes = notes
                print("解析完成，找到 \(notes.count) 条笔记")
                if notes.isEmpty {
                    self.errorMessage = "未能解析出任何笔记，请检查文件格式"
                }
            }
        } catch {
            print("读取文件失败: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "读取文件失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func parseContent(_ content: String) -> [Note] {
        var notes: [Note] = []
        
        // 使用 [法语表达]: 作为分隔符来分割多条笔记
        let noteBlocks = content.components(separatedBy: "[法语表达]:")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        print("找到 \(noteBlocks.count) 个笔记块")
        
        for block in noteBlocks {
            var expression = ""
            var translation = ""
            var note = ""
            
            // 分别提取各个部分
            let lines = block.components(separatedBy: .newlines)
            var currentSection = ""
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                if trimmedLine.starts(with: "[翻译]:") {
                    currentSection = "translation"
                    continue
                } else if trimmedLine.starts(with: "[NOTE]:") {
                    currentSection = "note"
                    continue
                } else if trimmedLine.isEmpty {
                    continue
                }
                
                switch currentSection {
                case "":  // 法语表达部分
                    if !trimmedLine.starts(with: "[") {
                        expression = trimmedLine
                    }
                case "translation":
                    if !trimmedLine.starts(with: "[") {
                        translation += trimmedLine + "\n"
                    }
                case "note":
                    if !trimmedLine.starts(with: "[") {
                        note += trimmedLine + "\n"
                    }
                default:
                    break
                }
            }
            
            // 清理和整理内容
            expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
            translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
            note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !expression.isEmpty {
                print("解析到笔记：")
                print("表达式: \(expression)")
                print("翻译: \(translation)")
                print("笔记: \(note)")
                
                notes.append(Note(expression: expression,
                                translation: translation,
                                note: note,
                                alternative: ""))
            }
        }
        
        return notes
    }
}
