/*
 * Canonical bounded task families for the humvar3 dynamic workflow split.
 *
 * These are top-level scheduler families. Supporting operations such as BAM
 * ingress, format conversion, annotation, publication, and export are owned by
 * one of these families instead of becoming independent global branches.
 */

def boundedTaskFamilies() {
    return [
        "basecalling",
        "mapping",
        "sample_aggregation",
        "variant_calling",
        "methylation",
        "cnv",
        "str",
        "reporting",
    ]
}

def taskFamilyOwners() {
    return [
        "basecalling": ["pod5_to_bam", "dorado"],
        "mapping": ["bam_ingress", "cram_conversion", "ubam_conversion", "remapping"],
        "sample_aggregation": ["per_sample_merge", "per_sample_refresh", "coverage_input_projection"],
        "variant_calling": ["snp_calling", "sv_calling", "phasing", "haplotagging", "annotation"],
        "methylation": ["modified_base_calling", "modkit", "phased_methylation"],
        "cnv": ["spectre", "qdnaseq"],
        "str": ["straglr", "sex_prerequisite"],
        "reporting": ["qc_metrics", "manifest_projection", "partner_export", "publication"],
    ]
}

def assertBoundedTaskFamily(String family) {
    if (!boundedTaskFamilies().contains(family)) {
        throw new IllegalArgumentException("unsupported task family '${family}'")
    }
    return family
}
