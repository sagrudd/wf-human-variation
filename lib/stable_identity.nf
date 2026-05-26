/*
 * Stable identity helpers for transitional wf-human-variation metadata.
 *
 * meta.alias remains the current output label. It is not durable identity.
 * Stable identity must be supplied explicitly by the controller or operator.
 */

def stableIdentityFromParams(Map meta, params) {
    def identity = [
        project: params.project,
        flowcell: params.flowcell,
        run_id: params.run_id,
        sample_id: params.sample_id,
        biosample_id: params.biosample_id,
        display_alias: meta.alias,
        observed_aliases: [meta.alias, meta.barcode].findAll { it }.unique()
    ]
    identity.identity_status = (
        identity.project
        && identity.flowcell
        && identity.run_id
        && identity.sample_id
        && identity.biosample_id
    ) ? "confirmed" : "unresolved"
    return identity
}

def withStableIdentity(Map meta, params) {
    return meta + stableIdentityFromParams(meta, params)
}
