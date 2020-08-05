import Foundation

public final class Cache<Key: Hashable, Value> {
  private let cache = NSCache<NSCacheKey, NSCacheValue>()
  private lazy var cacheDelegate = NSCacheDelegateObject(
    willEvictValue: { [weak self] _, key in self?.keys.remove(key) })
  
  private var keys = Set<Key>()
  
  public init() {
    cache.delegate = cacheDelegate
  }
  
  public func value(forKey key: Key) -> Value? {
    cache.object(forKey: NSCacheKey(key))?.value
  }
  
  public func set(_ value: Value, forKey key: Key) {
    cache.setObject(NSCacheValue(value, key: key), forKey: NSCacheKey(key))
    keys.insert(key)
  }
  
  public func removeValue(forKey key: Key) {
    cache.removeObject(forKey: NSCacheKey(key))
  }
  
  public func removeAllValues() { cache.removeAllObjects() }
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
  public convenience init(from decoder: Decoder) throws {
    self.init()
    let container = try decoder.singleValueContainer()
    let values = try container.decode([EncodedValue].self)
    values.forEach { set($0.value, forKey: $0.key) }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(keys.compactMap(encodedValue))
  }
  
  private func encodedValue(forKey key: Key) -> EncodedValue? {
    value(forKey: key).map { EncodedValue(key: key, value: $0) }
  }
  
  private struct EncodedValue: Codable {
    let key: Key
    let value: Value
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
