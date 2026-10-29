package yjson

import std.sync.*

/**
 * 定义第一方加速包的 V1 激活协议。
 *
 * 运行时先读取标识、协议和 ABI，再协调初始化与首次普通调用。应用通过 YJsonNativeAccel.initialize() 配置。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonAccelerationProviderV1 {
    /**
     * 提供用于冻结和重复初始化比较的 provider 标识。
     *
     * 运行时要求非空；冻结后以该字符串判断是否为同一 provider。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 非空且可稳定标识该 provider 的字符串。
     */
    func identity(): String
    /**
     * 提供加速激活协议版本。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 该 provider 使用的协议编号；当前运行时要求 1。
     */
    func protocolVersion(): Int64
    /**
     * 提供原生接口 ABI 版本。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 该 provider 使用的 ABI 编号；当前运行时要求 1。
     */
    func abiVersion(): Int64
    /**
     * 验证并激活 provider 依赖的实现。
     *
     * 运行时标记为初始化中后调用，执行时不持有运行时互斥锁。失败应抛出异常，运行时撤销本次初始化状态；回调不得递归初始化 provider 或使用普通 YJson 入口。
     *
     * @group 30-first-party-internal 第一方内部接口
     */
    func activate(): Unit
}

/**
 * 为加速 provider 提供完整的 V1 原生原语集合。
 *
 * 运行时在激活成功后统一安装，避免部分安装。供第一方包集成。
 *
 * @group 30-first-party-internal 第一方内部接口
 */
public interface JsonNativePrimitivesProviderV1 <: JsonAccelerationProviderV1 {
    /**
     * 取得待安装的 V1 原生原语集合。
     *
     * 在初始化取得执行权、activate 调用前取得；实际安装发生在 activate 成功后。
     *
     * @group 30-first-party-internal 第一方内部接口
     * @return 同时实现扫描、数字解析和写出原语的集合。
     */
    func primitives(): JsonNativeAccelerationPrimitivesV1
}

private const YJSON_ACCEL_PROTOCOL_V1: Int64 = 1
private const YJSON_ACCEL_ABI_V1: Int64 = 1
private const YJSON_RUNTIME_UNCONFIGURED: Int64 = 0
private const YJSON_RUNTIME_INITIALIZING: Int64 = 1
private const YJSON_RUNTIME_PURE_FROZEN: Int64 = 2
private const YJSON_RUNTIME_NATIVE_FROZEN: Int64 = 3

private let yJsonRuntimeMutex = Mutex()
private let yJsonRuntimeChanged = synchronized(yJsonRuntimeMutex) {
    yJsonRuntimeMutex.condition()
}
// Ordinary calls are overwhelmingly made after the process engine is frozen.
// Publish that terminal state atomically so the hot path never enters Mutex.
private let yJsonRuntimeFrozen = AtomicInt64(0)
// Package-visible test seam. The production path also updates the counter, so
// product-only builds do not acquire an unused test-helper declaration.
let yJsonRuntimeSlowFreezeEntriesForTest = AtomicInt64(0)
private var yJsonRuntimeState: Int64 = YJSON_RUNTIME_UNCONFIGURED
private var yJsonRuntimeProviderIdentity: String = ""
private var yJsonRuntimeInitializationOwner: Int64 = 0

/**
 * Freezes the portable engine on the first ordinary YJson call.
 */
func freezeYJsonRuntime(): Unit {
    if (yJsonRuntimeFrozen.load() != 0) { return }
    yJsonRuntimeSlowFreezeEntriesForTest.fetchAdd(1)
    synchronized(yJsonRuntimeMutex) {
        while (yJsonRuntimeState == YJSON_RUNTIME_INITIALIZING) {
            if (yJsonRuntimeInitializationOwner == Thread.currentThread.id) {
                throw JsonException(
                    "YJson cannot be used recursively while acceleration is initializing",
                    code: "acceleration_reentrant_use")
            }
            yJsonRuntimeChanged.wait()
        }
        if (yJsonRuntimeState == YJSON_RUNTIME_UNCONFIGURED) {
            yJsonRuntimeState = YJSON_RUNTIME_PURE_FROZEN
            yJsonRuntimeFrozen.store(1)
        }
    }
}

/**
 * 校验 provider 并冻结进程级加速状态。
 *
 * 元数据和 activate 在锁外执行；初始化与首次普通调用由同一状态机协调。成功后不能更换 provider；同一 identity 重复调用在元数据校验后返回。取得原语或激活失败时回到未配置状态。
 *
 * @group 30-first-party-internal 第一方内部接口
 * @param provider 实现 V1 协议的第一方加速 provider。
 * @throws JsonException 标识为空、协议或 ABI 不符、Pure 已冻结、provider 冲突、递归初始化，或激活抛出 JsonException；其他激活异常包装为 acceleration_initialization_failed。
 * @throws Exception provider 元数据或 primitives 回调抛出的异常原样传播。
 */
public func initializeYJsonAccelerationV1(provider: JsonAccelerationProviderV1): Unit {
    // Provider methods are callbacks into another package. Resolve metadata
    // before taking the runtime lock and run activation without holding it.
    let identity = provider.identity()
    let protocol = provider.protocolVersion()
    let abi = provider.abiVersion()
    if (identity.isEmpty()) {
        throw JsonException("Acceleration provider identity must not be empty",
            code: "acceleration_provider_identity_invalid")
    }
    if (protocol != YJSON_ACCEL_PROTOCOL_V1) {
        throw JsonException(
            "Acceleration protocol mismatch: expected 1, got ${protocol}",
            code: "acceleration_protocol_mismatch")
    }
    if (abi != YJSON_ACCEL_ABI_V1) {
        throw JsonException(
            "Acceleration ABI mismatch: expected 1, got ${abi}",
            code: "acceleration_abi_mismatch")
    }

    synchronized(yJsonRuntimeMutex) {
        while (yJsonRuntimeState == YJSON_RUNTIME_INITIALIZING) {
            if (yJsonRuntimeInitializationOwner == Thread.currentThread.id) {
                throw JsonException(
                    "Acceleration initialization cannot recursively initialize a provider",
                    code: "acceleration_reentrant_initialization")
            }
            yJsonRuntimeChanged.wait()
        }
        if (yJsonRuntimeState == YJSON_RUNTIME_PURE_FROZEN) {
            throw JsonException(
                "YJson is already frozen in portable mode; initialize acceleration before the first YJson call",
                code: "acceleration_initialized_too_late")
        }
        if (yJsonRuntimeState == YJSON_RUNTIME_NATIVE_FROZEN) {
            if (yJsonRuntimeProviderIdentity != identity) {
                throw JsonException(
                    "A different JSON acceleration provider is already active",
                    code: "acceleration_provider_conflict")
            }
            return
        }
        yJsonRuntimeState = YJSON_RUNTIME_INITIALIZING
        yJsonRuntimeInitializationOwner = Thread.currentThread.id
    }

    var primitives: Option<JsonNativeAccelerationPrimitivesV1> = None<JsonNativeAccelerationPrimitivesV1>
    try {
        match (provider) {
            case nativeProvider: JsonNativePrimitivesProviderV1 =>
                primitives = Some(nativeProvider.primitives())
            case _ => ()
        }
    } catch (error: Exception) {
        rollbackYJsonAccelerationInitialization()
        throw error
    }

    try {
        provider.activate()
    } catch (error: JsonException) {
        rollbackYJsonAccelerationInitialization()
        throw error
    } catch (error: Exception) {
        rollbackYJsonAccelerationInitialization()
        throw JsonException(
            "JSON acceleration initialization failed: ${error.message}",
            code: "acceleration_initialization_failed")
    }

    synchronized(yJsonRuntimeMutex) {
        // Install the primitive bundle only after activation validated the
        // linked native code. The slot is package-visible and updated under
        // the runtime lock, so hot paths observe either Pure or the complete
        // bundle.
        match (primitives) {
            case Some(bundle) => installJsonNativePrimitivesLocked(bundle)
            case None => ()
        }
        yJsonRuntimeProviderIdentity = identity
        yJsonRuntimeInitializationOwner = 0
        yJsonRuntimeState = YJSON_RUNTIME_NATIVE_FROZEN
        yJsonRuntimeFrozen.store(1)
        yJsonRuntimeChanged.notifyAll()
    }
}

private func rollbackYJsonAccelerationInitialization(): Unit {
    synchronized(yJsonRuntimeMutex) {
        yJsonRuntimeProviderIdentity = ""
        yJsonRuntimeInitializationOwner = 0
        yJsonRuntimeState = YJSON_RUNTIME_UNCONFIGURED
        yJsonRuntimeChanged.notifyAll()
    }
}

/**
 * 取得当前运行时的生成代码协议编号。
 *
 * 供生成代码拒绝协议不匹配的运行时。
 *
 * @group 20-generated-spi 生成代码 SPI
 * @return 当前协议编号 1。
 */
public func yJsonGeneratedProtocolVersion(): Int64 { 1 }
