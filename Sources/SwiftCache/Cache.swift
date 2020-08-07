import Foundation

public final class Cache<Key: Hashable, Value> {
  private let cache = NSCache<NSCacheKey, NSCacheValue>()
  private lazy var cacheDelegate = NSCacheDelegateObject(
    willEvictValue: { [weak self] _, key in self?.keys.remove(key) })
  
  private var keys = Set<Key>()
  
  private var _url: URL?
  private var _encoder: JSONEncoder? = JSONEncoder()
  private var writeToURL: (() throws -> Void)?
  
  public init() {
    cache.delegate = cacheDelegate
  }
  
  public func value(forKey key: Key) -> Value? {
    cache.object(forKey: NSCacheKey(key))?.value
  }
  
  public func trySet(_ value: Value, forKey key: Key) throws {
    cache.setObject(NSCacheValue(value, key: key), forKey: NSCacheKey(key))
    keys.insert(key)
    try writeToURL?()
  }
  
  public func tryRemoveValue(forKey key: Key) throws {
    cache.removeObject(forKey: NSCacheKey(key))
    try writeToURL?()
  }
  
  public func tryRemoveAllValues() throws {
    cache.removeAllObjects()
    try writeToURL?()
  }
}

public extension Cache {
  func set(_ value: Value, forKey key: Key) {
    try? trySet(value, forKey: key)
  }
  
  func removeValue(forKey key: Key) {
    try? tryRemoveValue(forKey: key)
  }
  
  func removeAllValues() { try? tryRemoveAllValues() }
}

public extension Cache {
  subscript(key: Key) -> Value? {
    get { value(forKey: key) }
    set {
      if let value = newValue { set(value, forKey: key) }
      else { removeValue(forKey: key) }
    }
  }
}

extension Cache: Codable where Key: Codable, Value: Codable {
  public var url: URL? {
    get { _url }
    set { _url = newValue; setWriteToURL() }
  }
  
  public var encoder: JSONEncoder? {
    get { _encoder }
    set { _encoder = newValue; setWriteToURL() }
  }
  
  private struct EncodedValue: Codable {
    let key: Key
    let value: Value
  }
  
  public convenience init(from decoder: Decoder) throws {
    self.init()
    let container = try decoder.singleValueContainer()
    let values = try container.decode([EncodedValue].self)
    values.forEach { set($0.value, forKey: $0.key) }
  }
  
  private func setWriteToURL() {
    guard let url = url, let encoder = encoder else { return }
    writeToURL = { try encoder.encode(self).write(to: url) }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(keys.compactMap(encodedValue))
  }
  
  private func encodedValue(forKey key: Key) -> EncodedValue? {
    value(forKey: key).map { EncodedValue(key: key, value: $0) }
  }
}

private extension Cache {
  final class NSCacheKey: NSObject {
    let key: Key
    
    init(_ key: Key) { self.key = key }
    
    override var hash: Int {
      var hasher = Hasher()
      hasher.combine(key)
      return hasher.finalize()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
      guard let cacheKey = object as? NSCacheKey else { return false }
      return cacheKey.key == key
    }
  }
}

private extension Cache {
  final class NSCacheValue {
    let value: Value
    let key: Key
    
    init(_ value: Value, key: Key) {
      self.value = value
      self.key = key
    }
  }
}

private extension Cache {
  final class NSCacheDelegateObject: NSObject, NSCacheDelegate {
    private let willEvictValue: (Value, Key) -> Void
    
    init(willEvictValue: @escaping (Value, Key) -> Void = { _, _ in }) {
      self.willEvictValue = willEvictValue
    }
    
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
      guard let cacheValue = obj as? NSCacheValue else { return }
      willEvictValue(cacheValue.value, cacheValue.key)
    }
  }
}
