// 示例使用真实 YJson reader/writer，回调只定义应用值的 JSON 表示。
class DocCallbackCodec<T> <: JsonCodec<T> {
    let encode: (T, JsonWriter) -> Unit
    let decode: (JsonReader) -> T

    init(encode: (T, JsonWriter) -> Unit, decode: (JsonReader) -> T) {
        this.encode = encode
        this.decode = decode
    }

    public func write(value: T, writer: JsonWriter): Unit { encode(value, writer) }
    public func read(reader: JsonReader): T { decode(reader) }
}

@JsonCodec
public struct DocCodecPoint {
    public var x: Int64 = 0
    public init(x: Int64) { this.x = x }
}

func docRequire(condition: Bool): Unit {
    if (!condition) { throw Exception("示例结果不符") }
}

@JsonCodec
public struct DocIgnoredField {
    public var visible: Int64 = 7
    @JsonIgnore
    public var secret: Int64 = 9
    public init() {}
}

@JsonCodec
public struct DocNullField {
    @JsonIncludeNull
    public var optional: Option<Int64> = None<Int64>
    public init() {}
}
