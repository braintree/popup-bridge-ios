import Foundation

// TODO: - Remove in favor of using URLComponents.queryItems
// Source: - https://stackoverflow.com/questions/46603220/how-do-i-convert-url-query-to-a-dictionary-in-swift
extension URL {
    
    var queryDictionary: [String: String] {
        guard let query = self.query else { return [:] }

        var queryStrings = [String: String]()
        for pair in query.components(separatedBy: "&") {

            let key = pair.components(separatedBy: "=")[0]

            let value = pair
                .components(separatedBy:"=")[1]
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? ""

            queryStrings[key] = value
        }
        return queryStrings
    }
}
