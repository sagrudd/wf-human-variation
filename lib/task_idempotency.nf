import groovy.json.JsonOutput
import java.security.MessageDigest

/*
 * Shared helper functions for the humvar3 task-idempotency contract.
 *
 * Future task-family refactors should derive task keys from stable ids plus
 * content/config digests, write internal products to task-cache paths, and
 * emit a completion marker only after required outputs exist.
 */

def canonicalTaskValue(value) {
    if (value instanceof Map) {
        return value.collectEntries { key, val -> [(key.toString()): canonicalTaskValue(val)] }.sort()
    }
    if (value instanceof Collection) {
        return value.collect { canonicalTaskValue(it) }
    }
    return value
}

def taskSha256(String text) {
    return MessageDigest.getInstance("SHA-256").digest(text.getBytes("UTF-8")).encodeHex().toString()
}

def safeTaskPathComponent(value) {
    def safe = value.toString().trim().replaceAll(/[^A-Za-z0-9_.-]+/, "-").replaceAll(/^-+|-+$/, "")
    return safe ?: "unknown"
}

def deterministicTaskKey(String taskFamily, Map fields) {
    if (!taskFamily?.trim()) {
        throw new IllegalArgumentException("taskFamily is required")
    }
    if (!fields) {
        throw new IllegalArgumentException("task key fields are required")
    }
    def canonical = JsonOutput.toJson(canonicalTaskValue(fields))
    return "${safeTaskPathComponent(taskFamily)}:${taskSha256(canonical)}"
}

def taskCacheDir(outDir, String taskFamily, String taskKey) {
    def digest = taskKey.tokenize(":")[-1]
    return "${outDir}/task-cache/${safeTaskPathComponent(taskFamily)}/${digest[0..1]}/${digest}"
}

def taskOutputPath(outDir, String taskFamily, String taskKey, String relativePath) {
    if (relativePath.startsWith("/") || relativePath.tokenize("/").contains("..")) {
        throw new IllegalArgumentException("relativePath must stay within the task directory")
    }
    return "${taskCacheDir(outDir, taskFamily, taskKey)}/${relativePath}"
}

def taskCompletionMarker(outDir, String taskFamily, String taskKey) {
    return "${taskCacheDir(outDir, taskFamily, taskKey)}/.gnostikon_task_complete.json"
}
