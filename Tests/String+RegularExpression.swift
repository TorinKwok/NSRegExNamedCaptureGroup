import Foundation

extension String {
  private func _ansiColor( _ formats: [ Int ] ) -> String {
    let joinedFormat = formats.map{ String( describing: $0 ) }.joined( separator: ";" )
    return "\u{001b}[\(joinedFormat)m"
    }

  private func _ansiColor( _ format: Int ) -> String {
    return _ansiColor( [ format ] )
    }

  private var _ansiColorNone: String {
    return _ansiColor( 0 )
    }

  var boldInTerminal: String {
    return _ansiColor( 1 ) + self + _ansiColorNone
    }

  var highlightedInTerminal: String {
    return _ansiColor( 7 ) + self + _ansiColorNone
    }
  }

infix operator =~: LogicalConjunctionPrecedence

extension String {
  var regularExpression: NSRegularExpression? {
    return try? self.regularExpression(
      options: [
          .caseInsensitive
        , .allowCommentsAndWhitespace
        , .anchorsMatchLines 
        ] )
    }

  func regularExpression( options: NSRegularExpression.Options = [] ) throws -> NSRegularExpression {
    return try NSRegularExpression( pattern: self, options: options )
    }

  static func =~( text: String, regex: NSRegularExpression ) -> [ NSTextCheckingResult ] {
    return regex.matches( in: text, range: NSMakeRange( 0, text.utf16.count ) )
    }

  static func =~( text: String, regex: NSRegularExpression ) -> Bool {
    return ( text =~ regex ).count > 0
    }

  static func =~( text: String, regex: NSRegularExpression )
    -> ( /*template:*/ String ) -> String {
    return { template in
      regex.stringByReplacingMatches(
          in: text
        , options: []
        , range: NSMakeRange( 0, text.utf16.count )
        , withTemplate: template
        )
      }
    }
  }
