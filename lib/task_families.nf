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
        "family_germline_snp",
        "family_joint_genotyping",
        "family_pedigree_phasing",
        "family_haplotagging",
        "family_sv_calling",
        "family_sv_merging",
        "family_mendelian_assessment",
        "somatic_qc",
        "somatic_tumour_only_snv",
        "somatic_paired_snv",
        "somatic_tumour_only_sv",
        "somatic_paired_sv",
        "somatic_methylation_aggregation",
        "somatic_differential_methylation",
        "somatic_annotation",
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
        "family_germline_snp": [
            "clair3_nova_candidate_selection",
            "clair3_nova_denovo_calling",
            "clair3_nova_merge_sort",
            "family_small_variant_inputs",
        ],
        "family_joint_genotyping": ["glnexus", "joint_small_variant_genotyping"],
        "family_pedigree_phasing": ["whatshap_phase", "pedigree_consistency_filter"],
        "family_haplotagging": ["whatshap_haplotag", "family_haplotagged_alignment_outputs"],
        "family_sv_calling": ["sniffles_per_member_snf", "family_sv_inputs"],
        "family_sv_merging": ["sniffles_joint_sv_merge"],
        "family_mendelian_assessment": ["rtg_mendelian", "family_inheritance_metrics"],
        "somatic_qc": ["somatic_role_coverage_qc", "somatic_shared_region_projection"],
        "somatic_tumour_only_snv": ["clairs_to", "tumour_only_small_variant_calling", "non_somatic_database_filtering"],
        "somatic_paired_snv": ["clairs", "paired_candidate_extraction", "paired_pileup_tensor_prediction", "paired_full_alignment_tensor_prediction", "paired_final_vcf_merge", "paired_haplotype_filtering"],
        "somatic_tumour_only_sv": ["severus_tumour_only", "somatic_sv_asset_validation"],
        "somatic_paired_sv": ["severus_paired", "somatic_sv_asset_validation"],
        "somatic_methylation_aggregation": ["modkit_role_aggregation", "bedmethyl_split", "dss_input_projection"],
        "somatic_differential_methylation": ["dss_dml", "dss_dmr", "paired_methylation_comparison"],
        "somatic_annotation": ["snpeff", "snpsift", "somatic_annotation_projection"],
    ]
}

def assertBoundedTaskFamily(String family) {
    if (!boundedTaskFamilies().contains(family)) {
        throw new IllegalArgumentException("unsupported task family '${family}'")
    }
    return family
}
