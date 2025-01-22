import Foundation
import SwiftUI

class AnkiConnector: ObservableObject {
    @Published var isAnkiRunning = false
    private let ankiConnectUrl = "http://127.0.0.1:8765"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    func checkAnkiRunning() {
        let request = createAnkiRequest(action: "version", params: [:])
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let _ = data {
                    self?.isAnkiRunning = true
                } else {
                    self?.isAnkiRunning = false
                }
            }
        }.resume()
    }
    
    func startAnki() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Anki"]
        
        do {
            try process.run()
            // 等待几秒钟让 Anki 启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.checkAnkiRunning()
            }
        } catch {
            print("Failed to start Anki: \(error.localizedDescription)")
        }
    }
    
    func createCard(expression: String, translation: String, note: String, alternative: String, completion: @escaping (Bool, String) -> Void) {
        print("开始创建笔记：")
        print("表达式: \(expression)")
        print("翻译: \(translation)")
        print("笔记: \(note)")
        
        createDeckIfNeeded { [weak self] success in
            guard success else {
                print("创建牌组失败")
                completion(false, "创建牌组失败")
                return
            }
            
            guard let self = self else { return }
            
            let fields: [String: String] = [
                "Expression": expression.trimmingCharacters(in: .whitespaces),
                "Translation": translation,
                "Note": note,
                "Alternative": alternative,
                "法语表达": expression.trimmingCharacters(in: .whitespaces),
                "翻译": translation,
                "NOTE": note,
                "Audio": "",
                "Image": "",
                "Hint": "",
                "Extra": ""
            ]
            
            let params: [String: Any] = [
                "note": [
                    "deckName": self.getCurrentDeckName(),
                    "modelName": "French Listening",
                    "fields": fields,
                    "options": [
                        "allowDuplicate": false
                    ],
                    "tags": ["AnkiMaker"]
                ]
            ]
            
            print("发送到Anki的参数: \(params)")
            
            let request = self.createAnkiRequest(action: "addNote", params: params)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("网络错误: \(error)")
                        completion(false, "网络错误：\(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        print("未收到响应数据")
                        completion(false, "未收到响应数据")
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("Anki响应: \(json)")
                            
                            if let error = json["error"] as? String {
                                if error.contains("duplicate") {
                                    completion(false, "重复的笔记")
                                } else {
                                    completion(false, "Anki错误：\(error)")
                                }
                                return
                            }
                            
                            if let result = json["result"] {
                                completion(true, "笔记创建成功")
                            } else {
                                completion(false, "创建笔记失败")
                            }
                        }
                    } catch {
                        print("解析响应失败: \(error)")
                        completion(false, "数据解析错误")
                    }
                }
            }.resume()
        }
    }
    
    private func createDeckIfNeeded(completion: @escaping (Bool) -> Void) {
        let deckName = getCurrentDeckName()
        print("尝试创建牌组：\(deckName)")
        
        let params: [String: Any] = [
            "deck": deckName
        ]
        
        let request = createAnkiRequest(action: "createDeck", params: params)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("创建牌组网络错误：\(error)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("创建牌组没有返回数据")
                    completion(false)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("创建牌组响应：\(json)")
                        if let error = json["error"] as? String {
                            print("创建牌组错误：\(error)")
                            completion(false)
                        } else {
                            print("牌组创建成功")
                            completion(true)
                        }
                    } else {
                        print("创建牌组响应格式错误")
                        completion(false)
                    }
                } catch {
                    print("解析创建牌组响应失败：\(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func getCurrentDeckName() -> String {
        return "French::\(dateFormatter.string(from: Date()))"
    }
    
    private func createAnkiRequest(action: String, params: [String: Any]) -> URLRequest {
        var request = URLRequest(url: URL(string: ankiConnectUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData: [String: Any] = [
            "action": action,
            "version": 6,
            "params": params
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestData)
        return request
    }
}
