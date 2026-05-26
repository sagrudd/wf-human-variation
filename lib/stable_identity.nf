/*
 * Stable identity helpers for transitional wf-human-variation metadata.
 *
 * meta.alias remains the current output label. It is not durable identity.
 * Stable identity must be supplied explicitly by the controller or operator.
 */

def parseSampleIdMap(def sampleIdParam) {
    String sampleIds = sampleIdParam?.toString() ?: ""
    if (!sampleIds.contains("=")) {
        return [:]
    }
    return sampleIds
        .split(/[,;]/)
        .findAll { it.trim() }
        .collectEntries { entry ->
            def parts = entry.split("=", 2)
            if (parts.size() != 2 || !parts[0].trim() || !parts[1].trim()) {
                throw new IllegalArgumentException("Invalid --sample_id mapping entry '${entry}'. Use alias=sample_id pairs.")
            }
            [(parts[0].trim()): parts[1].trim()]
        }
}

def stableSampleIdForMeta(Map meta, params) {
    if (meta.sample_id) {
        return meta.sample_id
    }
    def sampleIdMap = parseSampleIdMap(params.sample_id)
    if (sampleIdMap) {
        def sampleId = sampleIdMap[meta.alias] ?: sampleIdMap[meta.barcode]
        if (!sampleId) {
            throw new IllegalArgumentException("No --sample_id mapping found for alias '${meta.alias}'.")
        }
        return sampleId
    }
    return params.sample_id
}

def stableIdentityFromParams(Map meta, params) {
    def sampleId = stableSampleIdForMeta(meta, params)
    def identity = [
        project: params.project,
        flowcell: params.flowcell,
        run_id: params.run_id,
        sample_id: sampleId,
        display_alias: meta.alias,
        observed_aliases: [meta.alias, meta.barcode].findAll { it }.unique()
    ]
    identity.identity_status = identity.sample_id ? "confirmed" : "unresolved"
    return identity
}

def withStableIdentity(Map meta, params) {
    return meta + stableIdentityFromParams(meta, params)
}
