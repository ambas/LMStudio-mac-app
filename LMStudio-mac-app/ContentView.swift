//
//  ContentView.swift
//  LMStudio-mac-app
//
//  Created by Ambas Chobsanti on 2024/05/14.
//

import Foundation
import SwiftUI

let sampleMessage = """
A rhyming answer, I shall provide with flair!

There are **4** messages related to code styling that can be fixed by an auto code formatter:

1. Indentation (consistent spacing)
2. Line breaks (consistent line wrapping)
3. Whitespace (trailing spaces and tabs)
4. Quotes (consistent use of double quotes or backticks)

These formatting issues can be easily resolved with a code beautifier or a linter!
"""

struct ContentView: View {
    
    @State var prompt = ""
    
    @ObservedObject var model = Model()
    
    var body: some View {
        VStack {
            ScrollView {
                Text(model.contentData)
            }
            TextEditor(text: $prompt)
                .frame(height: 100)
            Button("Send") {
                model.tap(msg: prompt)
            }
        }
        .padding()
    }
}

final class Model: ObservableObject {
    
    @Published var contentData = ""
    // MARK: - Model
    struct Model: Codable {
        let id, object: String
        let created: Int
        let model: String
        let choices: [Choice]
        let usage: Usage
    }

    // MARK: - Choice
    struct Choice: Codable {
        let index: Int
        let message: ModelMessage
        let finishReason: String

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    // MARK: - Message
    struct ModelMessage: Codable {
        let role, content: String
    }

    // MARK: - Usage
    struct Usage: Codable {
        let promptTokens, completionTokens, totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct RequestPayload: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int
        let stream: Bool
        
        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case maxTokens = "max_tokens"
            case stream
        }
    }

    func loadFileContentFromDocumentsDirectory(_ fileName: String) -> String? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return fileContent
        } catch {
            print("Error reading file: \(error)")
            return nil
        }
    }

    func request() -> URLRequest {
        var request = URLRequest(url: URL(string: "http://localhost:1234/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }


    var content = ""

    func payload() ->  RequestPayload {
        RequestPayload(model: "lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF",
                       messages: [
                        Message(role: "system", content: "Always answer in rhymes."),
                        Message(role: "user", content: content)
                       ],
                       temperature: 0.7,
                       maxTokens: -1,
                       stream: false
        )
    }
    func tap(msg: String) {
        contentData = "Loading"
        Task {
            await run(msg: msg)
        }
    }
    
    func run(msg: String) async {
        content = msg
        do {
            let jsonData = try JSONEncoder().encode(payload())
            var request = request()
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let serialize = JSONDecoder()
                let responseData = try serialize.decode(Model.self, from: data)
                await MainActor.run {
                    contentData = responseData.choices.first!.message.content
                }
            } else {
                print("Request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        } catch {
            print("Error: \(error)")
        }
    }

    
}

#Preview {
    ContentView()
}
