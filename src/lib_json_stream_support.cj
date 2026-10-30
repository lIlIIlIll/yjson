package yjson

import std.collection.*
import std.io.*

/**
 * 在内存中累积写出字节的 OutputStream。
 *
 * write 复制传入字节，flush 无操作。没有容量预算；限制 JSON 输出大小应传入 JsonWriteOptions。toByteArray 返回副本，适合测试、小文档和已有内存缓冲的消费方。
 *
 * @example 调用并检查结果 {run}
 * ```cangjie
 * let output = YJsonMemoryOutputStream()
 * JsonNode.parse("[1]").writeJson(output)
 * println(output.toUtf8String())
 * ```
 * ```output
 * [1]
 * ```
 * @group 10-application 应用 API
 */
public class YJsonMemoryOutputStream <: OutputStream {
    private let buffer = ArrayList<Byte>()
    /**
     * 将字节副本追加到缓冲末尾。
     *
     * @param bytes 要追加的任意字节；不要求单次写入组成完整 UTF-8。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let output = YJsonMemoryOutputStream()
     * let bytes = "ok".toArray()
     * output.write(bytes)
     * bytes[0] = b'x'
     * println(output.toUtf8String())
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public func write(bytes: Array<Byte>): Unit { buffer.add(all: bytes) }
    /**
     * 刷新内存流；所有写入已在缓冲中，本操作不改变内容。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let output = YJsonMemoryOutputStream()
     * output.write("ok".toArray())
     * output.flush()
     * println(output.toUtf8String())
     * ```
     * ```output
     * ok
     * ```
     * @group 10-application 应用 API
     */
    public func flush(): Unit {}
    /**
     * 复制当前累积字节。
     *
     * @return 独立的字节数组；修改它不会修改流内缓冲。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let output = YJsonMemoryOutputStream()
     * output.write("ok".toArray())
     * let snapshot = output.toByteArray()
     * snapshot[0] = b'x'
     * println(snapshot[0] == b'x' && output.toUtf8String() == "ok")
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func toByteArray(): Array<Byte> { buffer.toArray() }
    /**
     * 将完整缓冲按 UTF-8 解码为字符串。
     *
     * @return 当前缓冲的字符串副本。
     * @throws IllegalArgumentException 缓冲包含无效 UTF-8。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let output = YJsonMemoryOutputStream()
     * output.write("你好".toArray())
     * println(output.toUtf8String())
     * ```
     * ```output
     * 你好
     * ```
     * @group 10-application 应用 API
     */
    public func toUtf8String(): String { String.fromUtf8(toByteArray()) }
}

/**
 * 从内存中的 UTF-8 字节或文本顺序读取的 InputStream。
 *
 * read 和 readRemainingBytes 共用一个游标，消耗的数据不会再次返回。字节构造器借用传入数组；读取期间不要修改该数组。此类本身不校验 JSON 或 UTF-8。
 * @group 10-application 应用 API
 */
public class YJsonByteArrayInputStream <: InputStream {
    private let bytes: Array<Byte>
    private var start: Int64 = 0
    private var remain: Int64

    /**
     * 创建借用给定字节数组的输入流。
     *
     * @param bytes 借用的输入字节；流未读完时不要修改它。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let input = YJsonByteArrayInputStream("[1]".toArray())
     * println(String.fromUtf8(input.readRemainingBytes()))
     * ```
     * ```output
     * [1]
     * ```
     * @group 10-application 应用 API
     */
    public init(bytes: Array<Byte>) {
        this.bytes = bytes
        this.remain = bytes.size
    }

    /**
     * 创建读取给定字符串 UTF-8 字节的输入流。
     *
     * @param text 作为输入存储保留的字符串。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let input = YJsonByteArrayInputStream("[1]")
     * println(String.fromUtf8(input.readRemainingBytes()))
     * ```
     * ```output
     * [1]
     * ```
     * @group 10-application 应用 API
     */
    public init(text: String) { this(unsafe { text.rawData() }) }

    /**
     * 从当前位置向缓冲填入尽可能多的字节。
     *
     * @param buf 接收缓冲；只改写前面返回长度范围内的元素。
     * @return 本次读取长度，最多为 buf.size；无剩余数据或缓冲为空时返回 0。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let input = YJsonByteArrayInputStream("abc")
     * let buffer = Array<Byte>(2, repeat: 0)
     * let count = input.read(buffer)
     * println(count == 2 && String.fromUtf8(buffer) == "ab" &&
     *     String.fromUtf8(input.readRemainingBytes()) == "c")
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func read(buf: Array<Byte>): Int64 {
        if (remain == 0) { return 0 }
        let size = if (buf.size <= remain) { buf.size } else { remain }
        bytes.copyTo(buf, start, 0, size)
        start += size
        remain -= size
        size
    }

    /**
     * 复制并消耗尚未读取的全部字节。
     *
     * @return 剩余字节的副本；调用后流到达末尾，再次读取返回空数组。
     *
     * @example 调用并检查结果 {run}
     * ```cangjie
     * let input = YJsonByteArrayInputStream("abc")
     * let bytes = input.readRemainingBytes()
     * println(String.fromUtf8(bytes) == "abc" && input.readRemainingBytes().isEmpty())
     * ```
     * ```output
     * true
     * ```
     * @group 10-application 应用 API
     */
    public func readRemainingBytes(): Array<Byte> {
        let result = bytes[start..start + remain]
        start += remain
        remain = 0
        result
    }

}
