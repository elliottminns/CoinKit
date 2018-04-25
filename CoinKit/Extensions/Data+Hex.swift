//
//  Data+Hex.swift
//  BIP39Kit
//
//  Created by Elliott Minns on 23/03/2018.
//  Copyright © 2018 Elliott Minns. All rights reserved.
//

import Foundation

public extension Data {
  public struct HexEncodingOptions: OptionSet {
    public let rawValue: Int
    static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }
  }
  
  func hexEncodedString(options: HexEncodingOptions = []) -> String {
    let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
    return map { String(format: format, $0) }.joined()
  }
}
