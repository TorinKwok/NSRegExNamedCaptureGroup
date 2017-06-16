import ObjectiveC
import Foundation

let selector = #selector( NSRegularExpression.matches(in:options:range:) )
let lhsMethod: Method = class_getInstanceMethod( NSRegularExpression.self, selector )
let lhsImp = method_getImplementation( lhsMethod )

fileprivate extension NSRegularExpression {
  @objc fileprivate func swizzling_matches(
      in text: String
    , options: NSRegularExpression.MatchingOptions = []
    , range: NSRange ) -> [ NSTextCheckingResult ] {
    print( "HOLLY!!!" )
    return self.swizzling_matches( in: text, options: options, range: range )
    }
  }

// let swizzlingSelector = #selector( NSRegularExpression.swizzling_matches(in:options:range:) )
// let rhsMethod: Method = class_getInstanceMethod( NSRegularExpression.self, swizzlingSelector )
// let rhsImp = method_getImplementation( rhsMethod )

// method_setImplementation( lhsMethod, rhsImp )
// method_setImplementation( rhsMethod, lhsImp )

/// Returns a range equivalent to the given `NSRange`,
/// or `nil` if the range can't be converted.
///
/// - Parameters:
///   - nsRange: The Foundation range to convert.
///
/// - Returns: A Swift range equivalent to `nsRange` 
///   if it is able to be converted. Otherwise, `nil`.
public extension String {
  func range( from nsRange: NSRange ) -> Range<Index>? {
    guard let swiftRange = nsRange.toRange() else {
      return nil
      }

    let utf16start = UTF16Index( swiftRange.lowerBound )
    let utf16end = UTF16Index( swiftRange.upperBound )

    guard let start = Index( utf16start, within: self )
      , let end = Index( utf16end, within: self ) else {
      return nil
      }

    return start..<end
    }
  }

// Matches all types of capture groups, including 
// named capture (?<Name> ... ), atomic grouping (?> ... ),
// conditional (? if then|else) and so on, except for
// grouping-only parentheses (?: ... ).
fileprivate let GenericCaptureGroupsPattern = try! NSRegularExpression(
    pattern: "\\((?!\\?:)[^\\(\\)]*\\)"
  , options: .dotMatchesLineSeparators
  )

// Further refinement.
// We will only work on Named Capture Groups (?<Name> ... ).
fileprivate let NamedCaptureGroupsPattern = try! NSRegularExpression(
    pattern: "^\\(\\?<([\\w\\a_-]*)>.*\\)$"
  , options: .dotMatchesLineSeparators
  )

fileprivate extension NSRegularExpression /* _NamedCaptureGroupsSupport */ {
  fileprivate typealias _GroupNamesSearchResult = (
      _outerOrdinaryCaptureGroup: NSTextCheckingResult
    , _innerRefinedNamedCaptureGroup: NSTextCheckingResult
    , _index: Int
    )

  fileprivate func _textCheckingResultsOfNamedCaptureGroups() throws
    -> [ String: _GroupNamesSearchResult ] {

    var groupNames = [ String: _GroupNamesSearchResult ]()

    let genericCaptureGroupsMatched = GenericCaptureGroupsPattern.matches(
        in: self.pattern
      , options: .withTransparentBounds
      , range: NSMakeRange( 0, self.pattern.utf16.count )
      )

    for ( index, ordiGroup ) in genericCaptureGroupsMatched.enumerated() {
      // Extract the sub-expression nested in `self.pattern`
      let genericCaptureGroupExpr: String = self.pattern[ self.pattern.range( from: ordiGroup.range )! ]

      print( "Gapturing/Grouping: qr/\(genericCaptureGroupExpr)/" )

      // Extract the part of Named Capture Group sub-expressions
      // nested in `genericCaptureGroupExpr`.
      let namedCaptureGroupsMatched = NamedCaptureGroupsPattern.matches(
          in: genericCaptureGroupExpr
        , options: .anchored
        , range: NSMakeRange( 0, genericCaptureGroupExpr.utf16.count )
        )

      if namedCaptureGroupsMatched.count > 0 {
        let firstNamedCaptureGroup = namedCaptureGroupsMatched[ 0 ]
        let namedCaptureExpr: String = genericCaptureGroupExpr[ genericCaptureGroupExpr.range( from: firstNamedCaptureGroup.range )! ]

        // In the case that `genericCaptureGroupExpr` is itself a NCG,
        // contents of `namedCaptureExpr` is completely identical to 
        // `genericCaptureGroupExpr`.

        print( "Capture Name: qr/\(namedCaptureExpr)/" )

        groupNames[ namedCaptureExpr ] = (
            _outerOrdinaryCaptureGroup: ordiGroup
          , _innerRefinedNamedCaptureGroup: firstNamedCaptureGroup
          , _index: index
          )
        }
      }

    return groupNames
    }
  }

/// __Named Capture Groups__ is an useful feature. Languages or libraries 
/// like Python, PHP's preg engine, and .NET languages support captures to 
/// named locations. Cocoa's NSRegEx implementation, according to Apple's 
/// official documentation, is based on ICU's regex implementation:
///
/// > The pattern syntax currently supported is that specified by ICU. 
/// > The ICU regular expressions are described at
/// > <http://userguide.icu-project.org/strings/regexp>.
///
/// And that page (on <icu-project.org>) claims that Named Capture Groups
/// are now supported, using the same syntax as .NET Regular Expressions:
///
/// > (?<name>...) Named capture group. The <angle brackets> are 
/// > literal - they appear in the pattern.
///
/// For example:
/// > \b**(?<Area>**\d\d\d)-(**?<Exch>**\d\d\d)-**(?<Num>**\d\d\d\d)\b
///
/// However, Apple's own documentation for NSRegularExpression does not 
/// list the syntax for Named Capture Groups, it only appears on ICU's
/// own documentation, suggesting that Named Capture Groups are a recent
/// addition and hence Cocoa's implementation has not integrated it yet.
///
/// This extension aims at providing developers using NSRegEx's with 
/// a solution to deal with Named Capture Groups within their regular 
/// expressions.
public extension NSRegularExpression /* NamedCaptureGroupsSupport */ {

  /// Returns a dictionary, after introspecting regex's own pattern, 
  /// containing all the Named Capture Group expressions found in
  /// receiver's pattern and their corresponding indices.
  ///
  /// - Returns: A dictionary containing the Named Capture Group expressions
  ///   plucked out and their corresponding indices.
  public func indicesOfNamedCaptureGroups() throws
    -> [ String: Int ] {
    var groupNames = [ String: Int ]()
    for ( name, ( _outerOrdinaryCaptureGroup: _, _innerRefinedNamedCaptureGroup: _, _index: index ) ) in
      try _textCheckingResultsOfNamedCaptureGroups() {
      groupNames[ name ] = index + 1
      }

    return groupNames
    }

  /// Returns a dictionary, after introspecting regex's own pattern, 
  /// containing all the Named Capture Group expressions found in
  /// receiver's pattern and the range of those expressions.
  ///
  /// - Returns: A dictionary containing the Named Capture Group expressions
  ///   plucked out and the range of those expressions.
  public func rangesOfNamedCaptureGroups( in match: NSTextCheckingResult ) throws
    -> [ String: NSRange ] {
    var nsRanges = [ String: NSRange ]()
    for ( name, ( _outerOrdinaryCaptureGroup: _, _innerRefinedNamedCaptureGroup: _, _index: index ) ) in
      try _textCheckingResultsOfNamedCaptureGroups() {
      nsRanges[ name ] = match.rangeAt( index + 1 )
      }

    return nsRanges
    }
  }

// public extension NSTextCheckingResult {
//   public func range( withName groupName: String? ) -> NSRange {
//     guard let groupName = groupName else {
//       return rangeAt( 0 )
//       }

//     // TODO: Remaining logic
//     }
//   }
