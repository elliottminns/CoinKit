//
//  Peer.swift
//  CoinKit
//
//  Created by Elliott Minns on 22/04/2018.
//  Copyright © 2018 Elliott Minns. All rights reserved.
//

import Foundation
import UIKit

extension Data {
  func chunks(by separator: Data) -> [Data] {
    let data = self
    var indicies: [Data.Index] = []
    var start: Data.Index = data.startIndex
    let end: Data.Index = data.endIndex
    while let range = data.range(of: separator, options: [], in: Range<Data.Index>(uncheckedBounds: (lower: start, upper: end))) {
      indicies.append(range.lowerBound)
      start = range.upperBound
    }
    
    let ranges = indicies.enumerated().compactMap { item -> Range<Data.Index>? in
      guard indicies.count > item.offset + 1 else { return nil }
      let start = item.element
      let end = indicies[item.offset + 1]
      let range = Range<Data.Index>(uncheckedBounds: (lower: start, upper: end))
      return range
    }
    
    return ranges.map { range in
      return Data(self[range])
    }
  }
}

protocol PeerDelegate: class {
  func peer(_ peer: Peer, didSendMessage message: Message)
  func peerDidDisconnect(_ peer: Peer)
}

public class Peer {
  let connection: Connection
  
  let params: Params
  
  let options: Options
  
  var handshaken: Bool = false
  
  var buffer: Data = Data()
  
  fileprivate(set) var handlers: Set<PeerHandler> = []
  
  unowned let delegate: PeerDelegate
  
  public var address: String {
    return connection.address
  }
  
  init(connection: Connection, params: Params, options: Options = Options(), delegate: PeerDelegate) {
    self.connection = connection
    self.params = params
    self.options = options
    self.delegate = delegate
    self.connection.delegate = self
  }
  
  public func ping() {
    let command = CommandType.Ping()
    self.add(handler: command) { _, _ in }
    send(command: command)
  }
  
  func add(handler: MessageHandler, callback: @escaping (Result<Message>, Peer) -> Void) {
    let peerHandler = PeerHandler(messageHandler: handler,
                                  delegate: self,
                                  peer: self,
                                  callback: callback,
                                  timeout: options.handshakeTimeout)
    handlers.insert(peerHandler)
  }
  
  public func get(block hash: String, callback: @escaping () -> Void) {
    let command = CommandType.GetData(inventory: [
      InventoryItem(type: .msgBlock, hash: hash)
      ])
    send(command: command)
  }
  
  /**
   * Gets the transactions by the TXIDs.
   *
   *
   */
  public func get(transactions: [String], callback: @escaping () -> Void) {
    
  }
  
  public func getHeaders(locator: [Data], stop: Data? = nil,
                         callback: @escaping (Result<Message>, Peer) -> Void) {
    let command = CommandType.GetHeaders(version: 60010,
                                         locators: locator,
                                         stopHash: stop)
    let handler = HeaderHandler()
    add(handler: handler, callback: callback)
    self.send(command: command)
  }
  
  public func sendVersion() {
    let command = CommandType.Version(
      version: 60010,
      userAgent: options.userAgent,
      relay: options.relay,
      peerAddress: address,
      port: UInt16(connection.port)
    )
    self.send(command: command)
  }
  
  public func send(command: Command) {
    let data = command.encode()
    let header = command.header(magic: params.magic)
    let full = header + data
    connection.write(data: full)
    let title = command.name
    print("Sent: \(title)")
  }
  
  public func successfulPing(nonce: UInt64) {
    handlers = handlers.filter {
      guard let command = $0.handler as? CommandType.Ping else { return true }
      return command.nonce != nonce
    }
  }
  
  func handle(message: Message) {
    let h = handlers.filter { $0.handles(message: message) }
    h.forEach { $0.handle(message: message, from: self) }
  }
}

extension Peer: ConnectionDelegate {
  func connection(_ connection: Connection, didReceiveData data: Data) {
    
    buffer.append(data)
    
    let separator = Data(params.magic.bytes.reversed())
    let chunks = buffer.chunks(by: separator)
    
    let messages = chunks.compactMap { chunk -> Message? in
      guard let message = Message(data: chunk, magicNumber: params.magic) else {
        return nil
      }
      buffer = Data(buffer[buffer.startIndex + chunk.count ..< buffer.endIndex])
      return message
    }
    
    messages.forEach(handle(message:))
    messages.forEach { delegate.peer(self, didSendMessage: $0) }
  }
  
  func connectionDidClose(_ connection: Connection) {
    delegate.peerDidDisconnect(self)
  }
}

public extension Peer {
  public struct Params {
    let magic: UInt32
  }
  
  public struct Options {
    public let relay: Bool
    
    public let requireBloom: Bool
    
    public let userAgent: String
    
    public let handshakeTimeout: TimeInterval
    
    public let pingInterval: TimeInterval
    
    public init(relay: Bool = false, requireBloom: Bool = true,
                handshakeTimeout: TimeInterval = 8.0, pingInterval: TimeInterval = 15.0) {
      self.relay = relay
      self.requireBloom = requireBloom
      self.userAgent = "/iOS:11.3/CoinKit:1.0"
      self.handshakeTimeout = handshakeTimeout
      self.pingInterval = pingInterval
    }
  }
}

extension Peer: PeerHandlerDelegate {
  func peerHandlerDidTimeout(handler: PeerHandler) {
    
  }
}
