import SwiftUI
import UniformTypeIdentifiers

struct Note: Identifiable {
    let id = UUID()
    let expression: String
    let translation: String
    let note: String
    let alternative: String
}

struct ContentView: View {
    @StateObject private var ankiConnector = AnkiConnector()
    @StateObject private var fileProcessor = FileProcessor()
    @State private var showFileImporter = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AnkiMaker")
                .font(.largeTitle)
                .padding()
            
            // Anki 连接状态
            HStack {
                Image(systemName: ankiConnector.isAnkiRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(ankiConnector.isAnkiRunning ? .green : .red)
                Text(ankiConnector.isAnkiRunning ? "Anki 已连接" : "Anki 未运行")
            }
            .padding()
            
            // 文件选择按钮
            Button(action: {
                showFileImporter = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16, weight: .medium))
                    Text("选择文本文件")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // 解析结果显示
            if !fileProcessor.notes.isEmpty {
                Text("已解析 \(fileProcessor.notes.count) 条笔记:")
                    .font(.headline)
                    .padding(.top)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(fileProcessor.notes) { note in
                            VStack(alignment: .leading, spacing: 12) {
                                // 法语表达
                                Text(note.expression)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(8)
                                
                                // 翻译
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("翻译")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(note.translation)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal)
                                
                                // 笔记
                                if !note.note.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("笔记")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                        Text(note.note)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                
                // 导入按钮
                Button(action: importToAnki) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .medium))
                        Text("导入到 Anki")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(minWidth: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ankiConnector.isAnkiRunning ? Color.green : Color.gray)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .disabled(!ankiConnector.isAnkiRunning)
                .padding(.vertical)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let fileURL = files.first {
                    print("选择的文件URL: \(fileURL)")
                    
                    // 开始访问文件
                    if fileURL.startAccessingSecurityScopedResource() {
                        defer {
                            fileURL.stopAccessingSecurityScopedResource()
                        }
                        
                        do {
                            // 检查文件是否存在
                            let fileExists = try fileURL.checkResourceIsReachable()
                            print("文件是否存在: \(fileExists)")
                            
                            // 获取文件属性
                            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                            print("文件大小: \(attributes[.size] ?? 0) bytes")
                            
                            // 处理文件
                            fileProcessor.processFile(at: fileURL)
                        } catch {
                            print("文件访问错误: \(error)")
                            alertMessage = "文件访问错误: \(error.localizedDescription)"
                            showAlert = true
                        }
                    } else {
                        print("无法访问文件")
                        alertMessage = "无法访问文件，请检查权限设置"
                        showAlert = true
                    }
                }
            case .failure(let error):
                print("文件选择错误: \(error)")
                alertMessage = "文件选择错误: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
        .onAppear {
            ankiConnector.checkAnkiRunning()
        }
    }
    
    private func importToAnki() {
        var successCount = 0
        var failureCount = 0
        
        for note in fileProcessor.notes {
            ankiConnector.createCard(
                expression: note.expression,
                translation: note.translation,
                note: note.note,
                alternative: note.alternative
            ) { success, message in
                if success {
                    successCount += 1
                } else {
                    failureCount += 1
                }
                
                if successCount + failureCount == fileProcessor.notes.count {
                    alertMessage = "导入完成：成功 \(successCount) 张，失败 \(failureCount) 张"
                    showAlert = true
                }
            }
        }
    }
}
