import Foundation

public enum TalonLiteStyle: String, Sendable, Equatable {
    case plain
    case hammer
    case camel
    case snake
    case kebab
}

public enum TalonLiteParseError: Error, Sendable, Equatable {
    case emptyInput
    case unknownToken(String)
    case misplacedStyleCommand(String)
    case missingContentAfterStyleCommand(String)

    public var isRecoverableUnknownToken: Bool {
        if case .unknownToken = self {
            return true
        }
        return false
    }

    public var message: String {
        switch self {
        case .emptyInput:
            return "No Talon tokens detected"
        case let .unknownToken(token):
            return "Unknown Talon token: \(token)"
        case let .misplacedStyleCommand(command):
            return "Style command must be first token: \(command)"
        case let .missingContentAfterStyleCommand(command):
            return "Style command requires at least one token: \(command)"
        }
    }
}

public struct TalonLiteParseResult: Sendable, Equatable {
    public let outputText: String
    public let style: TalonLiteStyle

    public init(outputText: String, style: TalonLiteStyle) {
        self.outputText = outputText
        self.style = style
    }
}

public enum TalonLiteParser {
    private enum Token: Equatable {
        case style(TalonLiteStyle)
        case text(String)
    }

    private static let talonAlphabet: [String: String] = [
        "air": "a", "bat": "b", "cap": "c", "drum": "d", "each": "e", "fine": "f", "gust": "g", "harp": "h",
        "sit": "i", "jury": "j", "crunch": "k", "look": "l", "made": "m", "near": "n", "odd": "o", "pit": "p",
        "quench": "q", "red": "r", "sun": "s", "trap": "t", "urge": "u", "vest": "v", "whale": "w", "plex": "x",
        "yank": "y", "zip": "z"
    ]

    private static let digitWords: [String: String] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9"
    ]

    private static let symbolWords: [String: String] = [
        "slash": "/",
        "plus": "+",
        "minus": "-"
    ]

    private static let directSymbols: [String: String] = [
        "/": "/", "+": "+", "-": "-", "(": "(", ")": ")"
    ]

    public static let grammarText = """
    Grammar:
    utterance := [style_command] token_sequence
    style_command := hammer | camel | snake | kebab
    token_sequence := token { token }
    token := talon_alphabet | digit_word | symbol_word | left_paren | right_paren | literal_word

    talon_alphabet := air bat cap drum each fine gust harp sit jury crunch look made near odd pit quench red sun trap urge vest whale plex yank zip
    digit_word := zero one two three four five six seven eight nine
    symbol_word := slash plus minus
    left_paren := "left paren"
    right_paren := "right paren"
    literal_word := lowercase alphabetic token, regex [a-z]+
    """

    public static func parse(_ transcript: String) throws -> TalonLiteParseResult {
        let tokens = try tokenize(transcript)
        guard !tokens.isEmpty else {
            throw TalonLiteParseError.emptyInput
        }

        let style: TalonLiteStyle
        let contentTokens: ArraySlice<Token>
        if case let .style(parsedStyle) = tokens[0] {
            style = parsedStyle
            contentTokens = tokens.dropFirst()
            if contentTokens.isEmpty {
                throw TalonLiteParseError.missingContentAfterStyleCommand(parsedStyle.rawValue)
            }
        } else {
            style = .plain
            contentTokens = tokens[...]
        }

        let pieces = contentTokens.map {
            switch $0 {
            case .style(let nested):
                return nested.rawValue
            case .text(let text):
                return text
            }
        }

        return TalonLiteParseResult(outputText: format(pieces: pieces, style: style), style: style)
    }

    private static func tokenize(_ transcript: String) throws -> [Token] {
        let words = transcript
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap(normalizedWord)

        var tokens: [Token] = []
        var index = 0

        while index < words.count {
            let current = words[index]

            if current == "left", index + 1 < words.count, words[index + 1] == "paren" {
                tokens.append(.text("("))
                index += 2
                continue
            }
            if current == "right", index + 1 < words.count, words[index + 1] == "paren" {
                tokens.append(.text(")"))
                index += 2
                continue
            }

            if let style = TalonLiteStyle(rawValue: current) {
                if tokens.isEmpty {
                    tokens.append(.style(style))
                } else {
                    throw TalonLiteParseError.misplacedStyleCommand(current)
                }
                index += 1
                continue
            }

            if let mapped = talonAlphabet[current] ?? digitWords[current] ?? symbolWords[current] ?? directSymbols[current] {
                tokens.append(.text(mapped))
                index += 1
                continue
            }

            guard current.allSatisfy(\.isLetter) else {
                throw TalonLiteParseError.unknownToken(current)
            }
            tokens.append(.text(current))
            index += 1
        }

        return tokens
    }

    private static func format(pieces: [String], style: TalonLiteStyle) -> String {
        switch style {
        case .plain:
            return pieces.joined()
        case .hammer:
            return pieces.map(capitalizeToken).joined()
        case .camel:
            guard let first = pieces.first else {
                return ""
            }
            let head = lowerToken(first)
            let tail = pieces.dropFirst().map(capitalizeToken).joined()
            return head + tail
        case .snake:
            return pieces.map(lowerToken).joined(separator: "_")
        case .kebab:
            return pieces.map(lowerToken).joined(separator: "-")
        }
    }

    private static func capitalizeToken(_ token: String) -> String {
        guard let first = token.first else {
            return token
        }
        return String(first).uppercased() + String(token.dropFirst()).lowercased()
    }

    private static func lowerToken(_ token: String) -> String {
        token.lowercased()
    }

    private static func normalizedWord(_ raw: Substring) -> String? {
        let token = String(raw)
        if token.isEmpty {
            return nil
        }
        if directSymbols[token] != nil {
            return token
        }

        let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:'\"“”‘’"))
        return trimmed.isEmpty ? nil : trimmed
    }
}
