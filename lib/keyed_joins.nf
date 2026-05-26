/*
 * Key helpers for bounded humvar3 Nextflow entries.
 *
 * Bounded entries should join by sample_id or by sample_id/reference_id. Do not
 * use unkeyed combine() or whole-channel collect() to establish task readiness.
 */

def sampleJoinKey(meta) {
    def key = meta.sample_id ?: meta.alias
    if (!key) {
        throw new IllegalArgumentException("sample join key requires sample_id")
    }
    return key
}

def sampleReferenceJoinKey(meta, referenceId) {
    if (!referenceId) {
        throw new IllegalArgumentException("sample/reference join key requires reference_id")
    }
    return [sampleJoinKey(meta), referenceId]
}

def keyBySample(channel) {
    return channel.map { Object... values ->
        def meta = values[-1]
        [sampleJoinKey(meta), *values]
    }
}

def dropJoinKey(channel) {
    return channel.map { Object... values -> values.drop(1) }
}
