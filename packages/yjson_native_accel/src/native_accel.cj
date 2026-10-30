package yjson_native_accel

import yjson_native_primitives.*

/**
 * 为普通 `YJson` 入口安装进程级 Native 加速。
 *
 * 在进程中第一次普通 `YJson` 调用前执行 `initialize()`，成功后继续使用普通读写 API。
 * 该类不提供独立 DOM 后端，原生临时资源由实现释放。
 * @group 10-application 应用 API
 */
public class YJsonNativeAccel {
    /**
     * 在普通 `YJson` 首次使用前验证并冻结 Native 加速配置。
     *
     * 验证 provider、协议、ABI 和 CPU 能力后发布初始化结果，同一 provider 的重复初始化是幂等操作。
     * 普通调用已经冻结 Pure、不同 provider 竞争或激活失败时报告异常，不会静默降级。
     * 初始化成功后不能卸载或更换 provider，并发首次使用与初始化由运行时状态机确定先后。
     *
     * @throws JsonException 初始化过晚、provider 冲突、协议或 ABI 不匹配、CPU 不支持，或者激活失败；错误码以 `acceleration_` 开头。
     *
     * @example 启动时初始化后使用普通 API（profile: native-accel） {run}
     * ```cangjie
     * YJsonNativeAccel.initialize()
     * YJsonNativeAccel.initialize()
     * let value = YJson.fromJson<Int64>("7")
     * println(YJson.toJson(value))
     * ```
     * ```output
     * 7
     * ```
     * @group 10-application 应用 API
     */
    public static func initialize(): Unit {
        initializeYJsonNativePrimitivesV1()
    }
}
