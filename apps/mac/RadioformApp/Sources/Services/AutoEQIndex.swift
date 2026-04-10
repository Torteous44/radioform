import Foundation

struct AutoEQEntry: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let source: String

    var parametricEQURL: URL? {
        let filename = "\(name) ParametricEQ.txt"
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let encodedFile = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
        return URL(string: "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/\(encodedPath)/\(encodedFile)")
    }
}

/// Fetches and searches the AutoEQ headphone index from GitHub
class AutoEQIndex: ObservableObject {
    static let shared = AutoEQIndex()

    @Published var entries: [AutoEQEntry] = []
    @Published var isLoading = false
    @Published var error: String?

    private var lastFetchDate: Date?
    private let cacheURL: URL

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let radioformDir = appSupport.appendingPathComponent("Radioform")
        try? FileManager.default.createDirectory(
            at: radioformDir, withIntermediateDirectories: true)
        cacheURL = radioformDir.appendingPathComponent("autoeq-index.txt")
    }

    func search(_ query: String) -> [AutoEQEntry] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return Array(entries
            .filter { $0.name.lowercased().contains(lowered) }
            .prefix(50))
    }

    func loadIfNeeded() {
        if !entries.isEmpty {
            if let lastFetch = lastFetchDate, Date().timeIntervalSince(lastFetch) > 86400 {
                fetchFromNetwork()
            }
            return
        }

        if let cached = loadCache() {
            entries = cached
            return
        }

        fetchFromNetwork()
    }

    func fetchProfile(_ entry: AutoEQEntry) async throws -> String {
        guard let url = entry.parametricEQURL else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return content
    }

    // MARK: - Private

    private func fetchFromNetwork() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        let url = URL(string: "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/INDEX.md")!

        URLSession.shared.dataTask(with: url) { [weak self] data, response, err in
            if let err = err {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error = err.localizedDescription
                }
                return
            }

            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error = "Failed to decode index"
                }
                return
            }

            let parsed = Self.parseIndex(content)

            DispatchQueue.main.async {
                self?.isLoading = false
                self?.entries = parsed
                self?.lastFetchDate = Date()
                self?.saveCache(content)
            }
        }.resume()
    }

    static func parseIndex(_ content: String) -> [AutoEQEntry] {
        let lines = content.components(separatedBy: "\n")
        var results: [AutoEQEntry] = []

        let pattern = #"^- \[(.+?)\]\(\./(.+?)\) by (.+?)(?:\s+on .+)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for line in lines {
            let nsLine = line as NSString
            guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else { continue }

            let name = nsLine.substring(with: match.range(at: 1))
            let rawPath = nsLine.substring(with: match.range(at: 2))
            let source = nsLine.substring(with: match.range(at: 3))
            let path = rawPath.removingPercentEncoding ?? rawPath

            results.append(AutoEQEntry(name: name, path: path, source: source))
        }

        return results
    }

    private func loadCache() -> [AutoEQEntry]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let content = String(data: data, encoding: .utf8) else { return nil }
        let parsed = Self.parseIndex(content)
        guard !parsed.isEmpty else { return nil }
        lastFetchDate = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate]) as? Date
        return parsed
    }

    private func saveCache(_ content: String) {
        try? content.data(using: .utf8)?.write(to: cacheURL, options: .atomic)
    }
}
