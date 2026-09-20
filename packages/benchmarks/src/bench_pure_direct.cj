package yjson_benchmarks

import std.env.*
import std.fs.*
import std.time.*

private let PURE_DIRECT_WAIT_TIMEOUT_NS: Int64 = 120_000_000_000
private let PURE_DIRECT_POLL_INTERVAL: Duration = Duration.millisecond * 10

func pureDirectCaseName(): String {
    getVariable("YJSON_PURE_DIRECT_CASE").getOrThrow({ =>
        Exception("YJSON_PURE_DIRECT_CASE is required")
    })
}

private func pureDirectControlDirectory(): String {
    let directory = getVariable("YJSON_PURE_DIRECT_CONTROL").getOrThrow({ =>
        Exception("YJSON_PURE_DIRECT_CONTROL is required")
    })
    if (!Path(directory).isAbsolute()) {
        throw Exception("YJSON_PURE_DIRECT_CONTROL must be absolute")
    }
    directory
}

private func publishPureDirectReady(path: String, payload: String): Unit {
    let temporary = "${path}.tmp"
    File.writeTo(temporary, unsafe { payload.rawData().clone() })
    rename(temporary, to: path)
}

func pureDirectAwaitRelease(caseName: String): Unit {
    let directory = pureDirectControlDirectory()
    let payload = "${caseName}\n"
    publishPureDirectReady("${directory}/ready", payload)

    let continuation = "${directory}/continue"
    let waitStart = MonoTime.now()
    while ((MonoTime.now() - waitStart).toNanoseconds() < PURE_DIRECT_WAIT_TIMEOUT_NS) {
        if (exists(continuation)) {
            let observed = String.fromUtf8(File.readFrom(continuation))
            if (observed != payload) {
                throw Exception("Pure direct continue file does not match case ${caseName}")
            }
            return
        }
        sleep(PURE_DIRECT_POLL_INTERVAL)
    }
    throw Exception("timed out waiting for Pure direct continue file for ${caseName}")
}

func pureDirectElapsed(start: MonoTime): Int64 {
    (MonoTime.now() - start).toNanoseconds()
}

func runPureDirectContinuous(
    caseName: String,
    warmupTargetNs: Int64,
    action: () -> Unit,
    validate: () -> Unit
): Unit {
    action()
    validate()
    pureDirectAwaitRelease(caseName)

    let warmupStart = MonoTime.now()
    var warmupNs: Int64 = 0
    while (warmupNs < warmupTargetNs) {
        action()
        warmupNs = pureDirectElapsed(warmupStart)
    }

    let operations = fixedBenchOperations(caseName)
    let sampleStart = MonoTime.now()
    for (_ in 0..operations) { action() }
    let elapsedNs = pureDirectElapsed(sampleStart)

    validate()
    pureDirectReport(caseName, operations, elapsedNs, warmupNs, 1)
}

func pureDirectReport(
    caseName: String,
    operations: Int64,
    elapsedNs: Int64,
    warmupNs: Int64,
    segments: Int64
): Unit {
    if (operations <= 0 || elapsedNs <= 0 || warmupNs <= 0 || segments <= 0) {
        throw Exception("Pure direct timing counters must be positive")
    }
    println(
        "YJSON_PURE_DIRECT_V1 case=${caseName} operations=${operations} " +
        "elapsed_ns=${elapsedNs} warmup_ns=${warmupNs} segments=${segments}"
    )
}
