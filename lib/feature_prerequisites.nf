/*
 * Explicit prerequisite map for bounded humvar3 entries.
 *
 * This file is a contract helper for the Python controller and new bounded
 * entries. It must not be used to hide feature activation inside global
 * booleans: returned prerequisites remain visible task-planning state.
 */

def explicitTaskPrerequisites(String taskFamily, String mode = "") {
    def family = taskFamily?.trim()
    def selectedMode = mode?.trim()?.toLowerCase()

    if (family == "str") {
        return [[
            type: "task_family",
            task_family: "variant_calling",
            required_output_kind: "haplotagged_contig_bams",
            required_state: "ready",
            missing_policy: "plan",
            reason: "str_requires_haplotagged_contig_bams",
            internal: true,
        ]]
    }

    if (family == "cnv" && (!selectedMode || selectedMode == "spectre")) {
        return [[
            type: "task_family",
            task_family: "variant_calling",
            required_output_kind: "snp_vcf",
            required_state: "ready",
            missing_policy: "plan",
            reason: "spectre_cnv_requires_snp_vcf",
            internal: true,
        ]]
    }

    if (family == "methylation" && ["phased", "haplotagged"].contains(selectedMode)) {
        return [[
            type: "task_family",
            task_family: "variant_calling",
            required_output_kind: "haplotagged_bam",
            required_state: "ready",
            missing_policy: "degrade",
            reason: "phased_methylation_uses_haplotagged_bam_when_available",
            internal: true,
        ]]
    }

    if (family == "reporting") {
        return [[
            type: "task_family_subset",
            task_families: ["sample_aggregation", "variant_calling", "methylation", "cnv", "str"],
            required_state: "completed_subset",
            minimum_count: 1,
            missing_policy: "block",
            reason: "reporting_requires_any_completed_analysis_subset",
            internal: false,
            allow_partial: true,
        ]]
    }

    return []
}
