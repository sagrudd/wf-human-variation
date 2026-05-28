#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { snp; snp_stats } from './workflows/wf-human-snp'
include { lookup_clair3_model } from './modules/local/wf-human-snp'

include { bam as sv } from './workflows/wf-human-sv'
include { output_sv } from './modules/local/wf-human-sv'

include { str as str_compat } from './workflows/wf-human-str'
include { output_str } from './modules/local/wf-human-str'

include { cnv as cnv_spectre } from './workflows/wf-human-cnv'

include { cnv as cnv_qdnaseq } from './workflows/wf-human-cnv-qdnaseq'

include { partners } from './workflows/partners'

include {
    mosdepth as mosdepth_input;
    mosdepth as mosdepth_downsampled;
    mosdepth as mosdepth_coverage;
    readStats;
    getAllChromosomesBed;
    publish_artifact;
    get_region_coverage;
    evaluateCoveragePass;
    evaluateCoveragePassWholeGenome;
    rejectedLowCoverage;
    getVersions;
    validateReferenceCompatibility;
    eval_downsampling;
    eval_downsampling_without_bed;
    downsampling;
    annotate_vcf as annotate_snp_vcf;
    concat_vcfs as concat_snp_vcfs;
    concat_vcfs as concat_refined_snp;
    sift_clinvar_vcf as sift_clinvar_snp_vcf;
    bed_filter;
    sanitise_bed;
    sanitise_bed as sanitise_coverage_bed;
    combine_metrics_json;
    output_cnv;
    infer_sex;
    haplocheck;
} from './modules/local/common'

include {
    getParams;
} from './lib/common.nf'

include {
    optionalBoundaryChannel;
    optionalBoundaryFile;
} from './lib/optional_inputs.nf'

include {
    withStableIdentity;
} from './lib/stable_identity.nf'

include {
    referenceCompatibilityRequirements;
} from './lib/reference_compatibility.nf'

include {
    boundedEntryContractJson;
    boundedMappingEntryParams;
    boundedSampleAggregationEntryParams;
    boundedVariantCallingEntryParams;
    boundedSomaticGermlineHelperEntryParams;
    boundedSomaticPhasingEntryParams;
    boundedSomaticHaplotaggingEntryParams;
    boundedFamilyGermlineSnpEntryParams;
    boundedFamilyGermlineSnpDenovoEntryParams;
    boundedFamilyGermlineSnpMergeEntryParams;
    boundedFamilyJointGenotypingEntryParams;
    boundedFamilyPedigreePhasingEntryParams;
    boundedFamilyHaplotaggingEntryParams;
    boundedFamilySvCallingEntryParams;
    boundedFamilySvMergingEntryParams;
    boundedFamilyMendelianAssessmentEntryParams;
    boundedSomaticQcEntryParams;
    boundedSomaticTumourOnlySnvEntryParams;
    boundedSomaticPairedSnvCandidateEntryParams;
    boundedSomaticPairedSnvPileupEntryParams;
    boundedSomaticPairedSnvFullAlignmentEntryParams;
    boundedSomaticPairedSnvMergeEntryParams;
    boundedSomaticTumourOnlySvEntryParams;
    boundedSomaticAnnotationEntryParams;
    boundedSomaticMethylationAggregationEntryParams;
    boundedCnvEntryParams;
    boundedStrEntryParams;
    boundedMethylationEntryParams;
} from './lib/bounded_entry.nf'

include {
    runBoundedMappingTask;
} from './modules/local/bounded_mapping'

include {
    runBoundedSampleAggregationTask;
} from './modules/local/bounded_sample_aggregation'

include {
    runBoundedSmallVariantTask;
} from './modules/local/bounded_variant_calling'
include {
    runBoundedSomaticGermlineHelperTask;
} from './modules/local/bounded_somatic_germline_helper'
include {
    runBoundedSomaticPhasingTask;
    runBoundedSomaticHaplotaggingTask;
} from './modules/local/bounded_somatic_phasing'
include {
    runBoundedStructuralVariantTask;
} from './modules/local/bounded_structural_variant_calling'

include {
    runBoundedTrioCandidateSelectionTask;
} from './modules/local/bounded_trio_candidate_selection'
include {
    runBoundedTrioDenovoCallingTask;
} from './modules/local/bounded_trio_denovo_calling'
include {
    runBoundedTrioMergeSortTask;
} from './modules/local/bounded_trio_merge_sort'
include {
    runBoundedFamilyJointGenotypingTask;
} from './modules/local/bounded_family_joint_genotyping'
include {
    runBoundedFamilyPedigreePhasingTask;
} from './modules/local/bounded_family_pedigree_phasing'
include {
    runBoundedFamilyHaplotaggingTask;
} from './modules/local/bounded_family_haplotagging'
include {
    runBoundedFamilySvCallingTask;
} from './modules/local/bounded_family_sv_calling'
include {
    runBoundedFamilySvMergingTask;
} from './modules/local/bounded_family_sv_merging'
include {
    runBoundedFamilyMendelianAssessmentTask;
} from './modules/local/bounded_family_mendelian_assessment'

include {
    runBoundedSomaticQcTask;
} from './modules/local/bounded_somatic_qc'

include {
    runBoundedSomaticTumourOnlySnvTask;
} from './modules/local/bounded_somatic_tumour_only_snv'

include {
    runBoundedSomaticPairedSnvCandidateTask;
    runBoundedSomaticPairedSnvPileupTask;
    runBoundedSomaticPairedSnvFullAlignmentTask;
    runBoundedSomaticPairedSnvMergeTask;
} from './modules/local/bounded_somatic_paired_snv'

include {
    runBoundedSomaticTumourOnlySvTask;
} from './modules/local/bounded_somatic_tumour_only_sv'

include {
    runBoundedSomaticAnnotationTask;
} from './modules/local/bounded_somatic_annotation'

include {
    runBoundedSomaticMethylationAggregationTask;
} from './modules/local/bounded_somatic_methylation_aggregation'

include {
    runBoundedSpectreCnvTask;
    runBoundedQdnaseqCnvTask;
} from './modules/local/bounded_cnv'

include {
    runBoundedStrTask;
} from './modules/local/bounded_str'

include {
    runBoundedMethylationTask;
} from './modules/local/bounded_methylation'

include {
    detect_basecall_model
} from './lib/model.nf'

include {
    ingress;
    cram_to_bam;
} from './lib/_ingress.nf'

include {
    prepare_reference;
} from './lib/reference.nf'

include {
    refine_with_sv;
    vcfStats;
    output_snp;
} from "./modules/local/wf-human-snp.nf"

include { 
    mod;
    validate_modbam;
    sample_probs;
} from './workflows/methyl'



workflow mapping {
    entry_contract = boundedMappingEntryParams(params)
    reads = Channel.fromPath(entry_contract.input_xam, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    runBoundedMappingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        reads,
        reference
    )
}

workflow sample_aggregation {
    entry_contract = boundedSampleAggregationEntryParams(params)
    mapped_xam = Channel.fromPath(entry_contract.mapped_xam, checkIfExists: true)
    mapped_xam_index = Channel.fromPath(entry_contract.mapped_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedSampleAggregationTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        mapped_xam,
        mapped_xam_index,
        reference,
        reference_index
    )
}

workflow variant_calling {
    entry_contract = boundedVariantCallingEntryParams(params)
    aggregate_xam = Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)
    aggregate_xam_index = Channel.fromPath(entry_contract.aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    if (entry_contract.variant_mode == "sv") {
        mosdepth_summary = Channel.fromPath(entry_contract.mosdepth_summary, checkIfExists: true)
        target_bed = Channel.fromPath(entry_contract.target_bed, checkIfExists: true)
        runBoundedStructuralVariantTask(
            Channel.value(entry_contract),
            Channel.value(boundedEntryContractJson(entry_contract)),
            aggregate_xam,
            aggregate_xam_index,
            reference,
            reference_index,
            mosdepth_summary,
            target_bed
        )
    }
    else {
        clair3_model = Channel.fromPath(entry_contract.clair3_model, type: "dir", checkIfExists: true)
        runBoundedSmallVariantTask(
            Channel.value(entry_contract),
            Channel.value(boundedEntryContractJson(entry_contract)),
            aggregate_xam,
            aggregate_xam_index,
            reference,
            reference_index,
            clair3_model
        )
    }
}

workflow somatic_germline_helper {
    entry_contract = boundedSomaticGermlineHelperEntryParams(params)
    helper_aggregate_xam = Channel.fromPath(entry_contract.helper_aggregate_xam, checkIfExists: true)
    helper_aggregate_xam_index = Channel.fromPath(entry_contract.helper_aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    clair3_model = Channel.fromPath(entry_contract.clair3_model, type: "dir", checkIfExists: true)
    runBoundedSomaticGermlineHelperTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        helper_aggregate_xam,
        helper_aggregate_xam_index,
        reference,
        reference_index,
        clair3_model
    )
}

workflow somatic_phasing {
    entry_contract = boundedSomaticPhasingEntryParams(params)
    input_vcf = Channel.fromPath(entry_contract.input_vcf, checkIfExists: true)
    input_vcf_index = Channel.fromPath(entry_contract.input_vcf_index, checkIfExists: true)
    role_aggregate_xam = Channel.fromPath(entry_contract.role_aggregate_xam, checkIfExists: true)
    role_aggregate_xam_index = Channel.fromPath(entry_contract.role_aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedSomaticPhasingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        input_vcf,
        input_vcf_index,
        role_aggregate_xam,
        role_aggregate_xam_index,
        reference,
        reference_index
    )
}

workflow somatic_haplotagging {
    entry_contract = boundedSomaticHaplotaggingEntryParams(params)
    somatic_phased_vcf = Channel.fromPath(entry_contract.somatic_phased_vcf, checkIfExists: true)
    somatic_phased_vcf_index = Channel.fromPath(entry_contract.somatic_phased_vcf_index, checkIfExists: true)
    role_aggregate_xam = Channel.fromPath(entry_contract.role_aggregate_xam, checkIfExists: true)
    role_aggregate_xam_index = Channel.fromPath(entry_contract.role_aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedSomaticHaplotaggingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        somatic_phased_vcf,
        somatic_phased_vcf_index,
        role_aggregate_xam,
        role_aggregate_xam_index,
        reference,
        reference_index
    )
}

workflow family_germline_snp {
    entry_contract = boundedFamilyGermlineSnpEntryParams(params)
    proband_snp_vcf = Channel.fromPath(entry_contract.proband_snp_vcf, checkIfExists: true)
    proband_snp_vcf_index = Channel.fromPath(entry_contract.proband_snp_vcf_index, checkIfExists: true)
    father_snp_vcf = Channel.fromPath(entry_contract.father_snp_vcf, checkIfExists: true)
    father_snp_vcf_index = Channel.fromPath(entry_contract.father_snp_vcf_index, checkIfExists: true)
    mother_snp_vcf = Channel.fromPath(entry_contract.mother_snp_vcf, checkIfExists: true)
    mother_snp_vcf_index = Channel.fromPath(entry_contract.mother_snp_vcf_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    clair3_nova_model = Channel.fromPath(entry_contract.clair3_nova_model, type: "dir", checkIfExists: true)
    runBoundedTrioCandidateSelectionTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        proband_snp_vcf,
        proband_snp_vcf_index,
        father_snp_vcf,
        father_snp_vcf_index,
        mother_snp_vcf,
        mother_snp_vcf_index,
        reference,
        reference_index,
        clair3_nova_model
    )
}

workflow family_germline_snp_denovo {
    entry_contract = boundedFamilyGermlineSnpDenovoEntryParams(params)
    trio_candidate_beds = Channel.fromPath(entry_contract.trio_candidate_beds, type: "dir", checkIfExists: true)
    proband_bam = Channel.fromPath(entry_contract.proband_bam, checkIfExists: true)
    proband_bam_index = Channel.fromPath(entry_contract.proband_bam_index, checkIfExists: true)
    father_bam = Channel.fromPath(entry_contract.father_bam, checkIfExists: true)
    father_bam_index = Channel.fromPath(entry_contract.father_bam_index, checkIfExists: true)
    mother_bam = Channel.fromPath(entry_contract.mother_bam, checkIfExists: true)
    mother_bam_index = Channel.fromPath(entry_contract.mother_bam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    clair3_nova_model = Channel.fromPath(entry_contract.clair3_nova_model, type: "dir", checkIfExists: true)
    runBoundedTrioDenovoCallingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        trio_candidate_beds,
        proband_bam,
        proband_bam_index,
        father_bam,
        father_bam_index,
        mother_bam,
        mother_bam_index,
        reference,
        reference_index,
        clair3_nova_model
    )
}

workflow family_germline_snp_merge {
    entry_contract = boundedFamilyGermlineSnpMergeEntryParams(params)
    trio_denovo_vcf_fragments = Channel.fromPath(entry_contract.trio_denovo_vcf_fragments, type: "dir", checkIfExists: true)
    trio_candidate_beds = Channel.fromPath(entry_contract.trio_candidate_beds, type: "dir", checkIfExists: true)
    snp_vcf = Channel.fromPath(entry_contract.snp_vcf, checkIfExists: true)
    snp_vcf_index = Channel.fromPath(entry_contract.snp_vcf_index, checkIfExists: true)
    snp_gvcf = Channel.fromPath(entry_contract.snp_gvcf, checkIfExists: true)
    snp_gvcf_index = Channel.fromPath(entry_contract.snp_gvcf_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedTrioMergeSortTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        trio_denovo_vcf_fragments,
        trio_candidate_beds,
        snp_vcf,
        snp_vcf_index,
        snp_gvcf,
        snp_gvcf_index,
        reference,
        reference_index
    )
}

workflow family_joint_genotyping {
    entry_contract = boundedFamilyJointGenotypingEntryParams(params)
    proband_snp_gvcf = Channel.fromPath(entry_contract.proband_snp_gvcf, checkIfExists: true)
    proband_snp_gvcf_index = Channel.fromPath(entry_contract.proband_snp_gvcf_index, checkIfExists: true)
    father_snp_gvcf = Channel.fromPath(entry_contract.father_snp_gvcf, checkIfExists: true)
    father_snp_gvcf_index = Channel.fromPath(entry_contract.father_snp_gvcf_index, checkIfExists: true)
    mother_snp_gvcf = Channel.fromPath(entry_contract.mother_snp_gvcf, checkIfExists: true)
    mother_snp_gvcf_index = Channel.fromPath(entry_contract.mother_snp_gvcf_index, checkIfExists: true)
    glnexus_config = Channel.fromPath(entry_contract.glnexus_config, checkIfExists: true)
    pedigree_snapshot = Channel.fromPath(entry_contract.pedigree_snapshot, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedFamilyJointGenotypingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        proband_snp_gvcf,
        proband_snp_gvcf_index,
        father_snp_gvcf,
        father_snp_gvcf_index,
        mother_snp_gvcf,
        mother_snp_gvcf_index,
        glnexus_config,
        pedigree_snapshot,
        reference,
        reference_index
    )
}

workflow family_pedigree_phasing {
    entry_contract = boundedFamilyPedigreePhasingEntryParams(params)
    family_joint_vcf = Channel.fromPath(entry_contract.family_joint_vcf, checkIfExists: true)
    family_joint_vcf_index = Channel.fromPath(entry_contract.family_joint_vcf_index, checkIfExists: true)
    pedigree_snapshot = Channel.fromPath(entry_contract.pedigree_snapshot, checkIfExists: true)
    proband_bam = Channel.fromPath(entry_contract.proband_bam, checkIfExists: true)
    proband_bam_index = Channel.fromPath(entry_contract.proband_bam_index, checkIfExists: true)
    father_bam = Channel.fromPath(entry_contract.father_bam, checkIfExists: true)
    father_bam_index = Channel.fromPath(entry_contract.father_bam_index, checkIfExists: true)
    mother_bam = Channel.fromPath(entry_contract.mother_bam, checkIfExists: true)
    mother_bam_index = Channel.fromPath(entry_contract.mother_bam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedFamilyPedigreePhasingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        family_joint_vcf,
        family_joint_vcf_index,
        pedigree_snapshot,
        proband_bam,
        proband_bam_index,
        father_bam,
        father_bam_index,
        mother_bam,
        mother_bam_index,
        reference,
        reference_index
    )
}

workflow family_haplotagging {
    entry_contract = boundedFamilyHaplotaggingEntryParams(params)
    pedigree_filtered_vcf = Channel.fromPath(entry_contract.pedigree_filtered_vcf, checkIfExists: true)
    pedigree_filtered_vcf_index = Channel.fromPath(entry_contract.pedigree_filtered_vcf_index, checkIfExists: true)
    proband_xam = Channel.fromPath(entry_contract.proband_xam, checkIfExists: true)
    proband_xam_index = Channel.fromPath(entry_contract.proband_xam_index, checkIfExists: true)
    father_xam = Channel.fromPath(entry_contract.father_xam, checkIfExists: true)
    father_xam_index = Channel.fromPath(entry_contract.father_xam_index, checkIfExists: true)
    mother_xam = Channel.fromPath(entry_contract.mother_xam, checkIfExists: true)
    mother_xam_index = Channel.fromPath(entry_contract.mother_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedFamilyHaplotaggingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        pedigree_filtered_vcf,
        pedigree_filtered_vcf_index,
        proband_xam,
        proband_xam_index,
        father_xam,
        father_xam_index,
        mother_xam,
        mother_xam_index,
        reference,
        reference_index
    )
}

workflow family_sv_calling {
    entry_contract = boundedFamilySvCallingEntryParams(params)
    aggregate_xam = Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)
    aggregate_xam_index = Channel.fromPath(entry_contract.aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    mosdepth_summary = Channel.fromPath(entry_contract.mosdepth_summary, checkIfExists: true)
    target_bed = Channel.fromPath(entry_contract.target_bed, checkIfExists: true)
    runBoundedFamilySvCallingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        aggregate_xam,
        aggregate_xam_index,
        reference,
        reference_index,
        mosdepth_summary,
        target_bed
    )
}

workflow family_sv_merging {
    entry_contract = boundedFamilySvMergingEntryParams(params)
    proband_snf = entry_contract.proband_snf ? Channel.fromPath(entry_contract.proband_snf, checkIfExists: true) : optionalBoundaryChannel()
    father_snf = entry_contract.father_snf ? Channel.fromPath(entry_contract.father_snf, checkIfExists: true) : optionalBoundaryChannel()
    mother_snf = entry_contract.mother_snf ? Channel.fromPath(entry_contract.mother_snf, checkIfExists: true) : optionalBoundaryChannel()
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    target_bed = Channel.fromPath(entry_contract.target_bed, checkIfExists: true)
    runBoundedFamilySvMergingTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        proband_snf,
        father_snf,
        mother_snf,
        reference,
        reference_index,
        target_bed
    )
}

workflow family_mendelian_assessment {
    entry_contract = boundedFamilyMendelianAssessmentEntryParams(params)
    family_joint_vcf = entry_contract.family_joint_vcf ? Channel.fromPath(entry_contract.family_joint_vcf, checkIfExists: true) : optionalBoundaryChannel()
    family_joint_vcf_index = entry_contract.family_joint_vcf_index ? Channel.fromPath(entry_contract.family_joint_vcf_index, checkIfExists: true) : optionalBoundaryChannel()
    family_sv_vcf = entry_contract.family_sv_vcf ? Channel.fromPath(entry_contract.family_sv_vcf, checkIfExists: true) : optionalBoundaryChannel()
    family_sv_vcf_index = entry_contract.family_sv_vcf_index ? Channel.fromPath(entry_contract.family_sv_vcf_index, checkIfExists: true) : optionalBoundaryChannel()
    reference_sdf = Channel.fromPath(entry_contract.reference_sdf, type: "dir", checkIfExists: true)
    pedigree_snapshot = Channel.fromPath(entry_contract.pedigree_snapshot, checkIfExists: true)
    runBoundedFamilyMendelianAssessmentTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        family_joint_vcf,
        family_joint_vcf_index,
        family_sv_vcf,
        family_sv_vcf_index,
        reference_sdf,
        pedigree_snapshot
    )
}

workflow somatic_tumour_only_snv {
    entry_contract = boundedSomaticTumourOnlySnvEntryParams(params)
    aggregate_xam = Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)
    aggregate_xam_index = Channel.fromPath(entry_contract.aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    clairs_to_model = Channel.fromPath(entry_contract.clairs_to_model, type: "dir", checkIfExists: true)
    clairs_to_database_bundle = Channel.fromPath(entry_contract.clairs_to_database_bundle, type: "dir", checkIfExists: true)
    runBoundedSomaticTumourOnlySnvTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        aggregate_xam,
        aggregate_xam_index,
        reference,
        reference_index,
        clairs_to_model,
        clairs_to_database_bundle
    )
}

workflow somatic_paired_snv_candidate {
    entry_contract = boundedSomaticPairedSnvCandidateEntryParams(params)
    tumour_aggregate_xam = Channel.fromPath(entry_contract.tumour_aggregate_xam, checkIfExists: true)
    tumour_aggregate_xam_index = Channel.fromPath(entry_contract.tumour_aggregate_xam_index, checkIfExists: true)
    normal_or_control_aggregate_xam = Channel.fromPath(entry_contract.normal_or_control_aggregate_xam, checkIfExists: true)
    normal_or_control_aggregate_xam_index = Channel.fromPath(entry_contract.normal_or_control_aggregate_xam_index, checkIfExists: true)
    normal_vcf = Channel.fromPath(entry_contract.normal_vcf, checkIfExists: true)
    normal_vcf_index = Channel.fromPath(entry_contract.normal_vcf_index, checkIfExists: true)
    shared_region_bed = Channel.fromPath(entry_contract.shared_region_bed, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    clairs_model = Channel.fromPath(entry_contract.clairs_model, type: "dir", checkIfExists: true)
    clairs_reference_bundle = Channel.fromPath(entry_contract.clairs_reference_bundle, type: "dir", checkIfExists: true)
    target_bed = entry_contract.target_bed ? Channel.fromPath(entry_contract.target_bed, checkIfExists: true) : optionalBoundaryChannel()
    genotyping_vcf = entry_contract.genotyping_vcf ? Channel.fromPath(entry_contract.genotyping_vcf, checkIfExists: true) : optionalBoundaryChannel()
    genotyping_vcf_index = entry_contract.genotyping_vcf_index ? Channel.fromPath(entry_contract.genotyping_vcf_index, checkIfExists: true) : optionalBoundaryChannel()
    runBoundedSomaticPairedSnvCandidateTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        tumour_aggregate_xam,
        tumour_aggregate_xam_index,
        normal_or_control_aggregate_xam,
        normal_or_control_aggregate_xam_index,
        normal_vcf,
        normal_vcf_index,
        shared_region_bed,
        reference,
        reference_index,
        clairs_model,
        clairs_reference_bundle,
        target_bed,
        genotyping_vcf,
        genotyping_vcf_index
    )
}

workflow somatic_paired_snv_pileup {
    entry_contract = boundedSomaticPairedSnvPileupEntryParams(params)
    tumour_aggregate_xam = Channel.fromPath(entry_contract.tumour_aggregate_xam, checkIfExists: true)
    tumour_aggregate_xam_index = Channel.fromPath(entry_contract.tumour_aggregate_xam_index, checkIfExists: true)
    normal_or_control_aggregate_xam = Channel.fromPath(entry_contract.normal_or_control_aggregate_xam, checkIfExists: true)
    normal_or_control_aggregate_xam_index = Channel.fromPath(entry_contract.normal_or_control_aggregate_xam_index, checkIfExists: true)
    candidate_bed = Channel.fromPath(entry_contract.candidate_bed, checkIfExists: true)
    candidate_variants = Channel.fromPath(entry_contract.candidate_variants, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    clairs_model = Channel.fromPath(entry_contract.clairs_model, type: "dir", checkIfExists: true)
    runBoundedSomaticPairedSnvPileupTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        tumour_aggregate_xam,
        tumour_aggregate_xam_index,
        normal_or_control_aggregate_xam,
        normal_or_control_aggregate_xam_index,
        candidate_bed,
        candidate_variants,
        reference,
        reference_index,
        clairs_model
    )
}

workflow somatic_paired_snv_full_alignment {
    entry_contract = boundedSomaticPairedSnvFullAlignmentEntryParams(params)
    tumour_alignment_xam = Channel.fromPath(entry_contract.tumour_alignment_xam, checkIfExists: true)
    tumour_alignment_xam_index = Channel.fromPath(entry_contract.tumour_alignment_xam_index, checkIfExists: true)
    normal_or_control_alignment_xam = Channel.fromPath(entry_contract.normal_or_control_alignment_xam, checkIfExists: true)
    normal_or_control_alignment_xam_index = Channel.fromPath(entry_contract.normal_or_control_alignment_xam_index, checkIfExists: true)
    candidate_bed = Channel.fromPath(entry_contract.candidate_bed, checkIfExists: true)
    candidate_variants = Channel.fromPath(entry_contract.candidate_variants, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    clairs_model = Channel.fromPath(entry_contract.clairs_model, type: "dir", checkIfExists: true)
    runBoundedSomaticPairedSnvFullAlignmentTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        tumour_alignment_xam,
        tumour_alignment_xam_index,
        normal_or_control_alignment_xam,
        normal_or_control_alignment_xam_index,
        candidate_bed,
        candidate_variants,
        reference,
        reference_index,
        clairs_model
    )
}

workflow somatic_paired_snv_merge {
    entry_contract = boundedSomaticPairedSnvMergeEntryParams(params)
    pileup_prediction_fragments = Channel.fromPath(entry_contract.pileup_prediction_fragments, type: "dir", checkIfExists: true)
    full_alignment_prediction_fragments = Channel.fromPath(entry_contract.full_alignment_prediction_fragments, type: "dir", checkIfExists: true)
    contigs_file = Channel.fromPath(entry_contract.contigs_file, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedSomaticPairedSnvMergeTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        pileup_prediction_fragments,
        full_alignment_prediction_fragments,
        contigs_file,
        reference,
        reference_index
    )
}

workflow somatic_qc {
    entry_contract = boundedSomaticQcEntryParams(params)
    tumour_regions = Channel.fromPath(entry_contract.tumour_mosdepth_regions, checkIfExists: true)
    normal_or_control_regions = Channel.fromPath(entry_contract.normal_or_control_mosdepth_regions, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    target_bed = entry_contract.target_bed ? Channel.fromPath(entry_contract.target_bed, checkIfExists: true) : optionalBoundaryChannel()
    runBoundedSomaticQcTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        tumour_regions,
        normal_or_control_regions,
        reference,
        target_bed
    )
}

workflow somatic_tumour_only_sv {
    entry_contract = boundedSomaticTumourOnlySvEntryParams(params)
    aggregate_xam = Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)
    aggregate_xam_index = Channel.fromPath(entry_contract.aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    pon_file = entry_contract.pon_file ? Channel.fromPath(entry_contract.pon_file, checkIfExists: true) : optionalBoundaryChannel()
    trf_bed = entry_contract.trf_bed ? Channel.fromPath(entry_contract.trf_bed, checkIfExists: true) : optionalBoundaryChannel()
    runBoundedSomaticTumourOnlySvTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        aggregate_xam,
        aggregate_xam_index,
        reference,
        reference_index,
        pon_file,
        trf_bed
    )
}

workflow somatic_annotation {
    entry_contract = boundedSomaticAnnotationEntryParams(params)
    source_vcf = Channel.fromPath(entry_contract.source_vcf, checkIfExists: true)
    source_vcf_index = Channel.fromPath(entry_contract.source_vcf_index, checkIfExists: true)
    snpeff_database = Channel.fromPath(entry_contract.snpeff_database, type: "dir", checkIfExists: true)
    clinvar_vcf = entry_contract.clinvar_vcf ? Channel.fromPath(entry_contract.clinvar_vcf, checkIfExists: true) : optionalBoundaryChannel()
    clinvar_vcf_index = entry_contract.clinvar_vcf_index ? Channel.fromPath(entry_contract.clinvar_vcf_index, checkIfExists: true) : optionalBoundaryChannel()
    sift_annotation = entry_contract.sift_annotation ? Channel.fromPath(entry_contract.sift_annotation, checkIfExists: true) : optionalBoundaryChannel()
    runBoundedSomaticAnnotationTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        source_vcf,
        source_vcf_index,
        snpeff_database,
        clinvar_vcf,
        clinvar_vcf_index,
        sift_annotation
    )
}

workflow somatic_methylation_aggregation {
    entry_contract = boundedSomaticMethylationAggregationEntryParams(params)
    role_aggregate_xam = Channel.fromPath(entry_contract.role_aggregate_xam, checkIfExists: true)
    role_aggregate_xam_index = Channel.fromPath(entry_contract.role_aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedSomaticMethylationAggregationTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        role_aggregate_xam,
        role_aggregate_xam_index,
        reference,
        reference_index
    )
}

workflow cnv {
    entry_contract = boundedCnvEntryParams(params)
    aggregate_xam = Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)
    aggregate_xam_index = Channel.fromPath(entry_contract.aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    if (entry_contract.cnv_mode == "spectre") {
        snp_vcf = Channel.fromPath(entry_contract.snp_vcf, checkIfExists: true)
        snp_vcf_index = Channel.fromPath(entry_contract.snp_vcf_index, checkIfExists: true)
        mosdepth_summary = Channel.fromPath(entry_contract.mosdepth_summary, checkIfExists: true)
        mosdepth_regions = Channel.fromPath(entry_contract.mosdepth_regions, checkIfExists: true)
        mosdepth_distribution = Channel.fromPath(entry_contract.mosdepth_distribution, checkIfExists: true)
        mosdepth_thresholds = Channel.fromPath(entry_contract.mosdepth_thresholds, checkIfExists: true)
        runBoundedSpectreCnvTask(
            Channel.value(entry_contract),
            Channel.value(boundedEntryContractJson(entry_contract)),
            aggregate_xam,
            aggregate_xam_index,
            reference,
            reference_index,
            snp_vcf,
            snp_vcf_index,
            mosdepth_summary,
            mosdepth_regions,
            mosdepth_distribution,
            mosdepth_thresholds
        )
    }
    else {
        runBoundedQdnaseqCnvTask(
            Channel.value(entry_contract),
            Channel.value(boundedEntryContractJson(entry_contract)),
            aggregate_xam,
            aggregate_xam_index,
            reference,
            reference_index
        )
    }
}

workflow str {
    entry_contract = boundedStrEntryParams(params)
    haplotagged_contig_manifest = Channel.fromPath(entry_contract.haplotagged_contig_manifest, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    repeat_bed = Channel.fromPath(entry_contract.repeat_bed, checkIfExists: true)
    variant_catalogue = Channel.fromPath(entry_contract.variant_catalogue, checkIfExists: true)
    runBoundedStrTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        haplotagged_contig_manifest,
        reference,
        reference_index,
        repeat_bed,
        variant_catalogue
    )
}

workflow methylation {
    entry_contract = boundedMethylationEntryParams(params)
    aggregate = Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)
    aggregate_index = Channel.fromPath(entry_contract.aggregate_xam_index, checkIfExists: true)
    haplotagged = entry_contract.methylation_mode == "phased" ?
        Channel.fromPath(entry_contract.haplotagged_xam, checkIfExists: true) :
        Channel.fromPath(entry_contract.aggregate_xam, checkIfExists: true)
    haplotagged_index = entry_contract.methylation_mode == "phased" ?
        Channel.fromPath(entry_contract.haplotagged_xam_index, checkIfExists: true) :
        Channel.fromPath(entry_contract.aggregate_xam_index, checkIfExists: true)
    reference = Channel.fromPath(entry_contract.reference_fasta, checkIfExists: true)
    reference_index = Channel.fromPath(entry_contract.reference_index, checkIfExists: true)
    runBoundedMethylationTask(
        Channel.value(entry_contract),
        Channel.value(boundedEntryContractJson(entry_contract)),
        aggregate,
        aggregate_index,
        haplotagged,
        haplotagged_index,
        reference,
        reference_index
    )
}

// Compatibility entrypoint workflow
workflow {
    WorkflowMain.initialise(workflow, params, log)

    Map colors = NfcoreTemplate.logColours(params.monochrome_logs)

    can_start = true

    if (!params.sample_id) {
        log.error(colors.red + "Stable sample identity is required. Provide --sample_id." + colors.reset)
        can_start = false
    }

    // Check if it is in genotyping mode
    if (params.snp && params.vcf_fn) {
        if (params.bed){
            throw new Exception(colors.red + "Clair3 cannot run with both --vcf_fn and --bed." + colors.reset)
        }
        log.warn ("Running Clair3 in genotyping mode with --vcf_fn will override --snp_min_af and --indel_min_af to 0.0.")
    }

    // check SV calling will be done when benchmarking SV calls
    if(params.sv_benchmark && !params.sv) {
        throw new Exception(colors.red + "Cannot benchmark SV subworkflow without running SV subworkflow! Enable the SV subworkflow with --sv." + colors.reset)
    }

    // If downsampling is required, check that the requested coverage is above the min threshold
    if(params.downsample_coverage) {
        if (params.downsample_coverage_target < params.bam_min_coverage){
            log.error (colors.red + "Downsampling target ${params.downsample_coverage_target} is lower than the minimum BAM coverage requested of ${params.bam_min_coverage}" + colors.reset)
            can_start = false
        }
    }

    // If coverage summaries are requested, check if BED files are provided and warn if they don't have 4 columns
    // Set create_bed_summary and create_coverage_bed_summary accordingly so we can avoid running mosdepth on incompatible BED files

    def create_bed_summary = false
    def create_coverage_bed_summary = false

    // check if a BED file has at least 4 columns
    def check_bed_has_name_col = { bed_file ->
        if (bed_file) {
            def col_size = file(bed_file).splitCsv(sep: '\t').first().size
            if (col_size < 4) {
                return false
            }
            return true
        }
        return false
    }

    // Check and set create_bed_summary if --bed provided
    if (params.bed) {
        create_bed_summary = check_bed_has_name_col(params.bed)
    }

    // check and set create_coverage_bed_summary if --coverage_bed provided
    // exit workflow if this BED file doesn't have at least 4 columns
    if (params.coverage_bed) {
        if (check_bed_has_name_col(params.coverage_bed)) {
            create_coverage_bed_summary = true
        }
        else {
            log.error (colors.red + "The provided BED file (${params.coverage_bed}) has fewer than 4 columns, and therefore a coverage summary can not be generated." + colors.reset)
            can_start = false
        }
    }

    // Programmatically define chromosome codes.
    // note that we avoid interpolation (eg. "${chr}N") to ensure that values
    // are Strings and not GStringImpl, ensuring that .contains works.
    ArrayList chromosome_codes = []
    ArrayList chromosomes = [1..22] + ["X", "Y", "M", "MT"]
    for (N in chromosomes.flatten()){
        chromosome_codes += ["chr" + N, "" + N]
    }

    // Trigger haplotagging
    def run_haplotagging = params.str || params.phased
    
    // Combine data for partners
    def run_partners = params.partner?: false
    // Trigger CRAM to BAM conversion (for qdnaseq)
    // This will:
    // - cause downsampling to always be emitted as BAM
    // - OR if not downsampling, cause (re)alignment to always be emitted as BAM
    // - OR if not downsampling or (re)aligning, explicitly convert input CRAM to BAM
    def convert_cram_to_bam = params.cnv && params.use_qdnaseq

    // User desired alignment extentions
    def desired_xam_ext = params.output_xam_fmt == "cram" ? ["cram", "crai"] : ["bam", "bai"]

    // Determine what extentions should be output by ingress
    // Note that ingress does not handle downsampling so we carve that case out here
    if (convert_cram_to_bam && !params.downsample_coverage) {
        // Force BAM if not downsampling and BAM is needed downstream
        ingress_ext = ['bam', 'bai']
    }
    else {
        // No need to force a BAM - do what the user wants
        ingress_ext = desired_xam_ext
    }

    // Set extensions for the final haplotagged XAM
    // CNV is run on the ingressed BAM channel,
    //   and STR is run on the intermediate phased BAM,
    //   so we are free to output CRAM here, if desired.
    def haplotagged_output_fmt = desired_xam_ext

    // Notify users that QDNAseq usage will override the format of output XAM
    if (convert_cram_to_bam && params.output_xam_fmt == "cram") {
        log.warn "CNV calling subworkflow using QDNAseq does not support CRAM, but you have selected CRAM for your output file format."
        log.warn "You do not need to do anything, but any alignment or realignment will ignore your CRAM selection and be written as BAM to maintain compatibility with QDNAseq."
    }

    // Trigger the SNP workflow based on a range of different conditions:
    def run_snp = params.snp || run_haplotagging || (params.cnv && !params.use_qdnaseq)

    reference = prepare_reference([
        "input_ref": params.ref,
        "output_cache": true,
        "output_mmi": false
    ])
    ref = reference.ref
    ref_index = reference.ref_idx
    ref_cache = reference.ref_cache
    // canonical ref and BAM channels to pass around to all processes
    ref_channel = ref
    | concat(ref_index)
    | concat(ref_cache)
    | flatten
    | buffer(size: 4)

    // ************************************************************************
    // Bail from the workflow for a reason we should have already specified
    if (!can_start){
        throw new Exception("The workflow could not be started.")
    }
    // ************************************************************************

    // Transitional Nextflow boundary for absent optional inputs. Controller
    // code must model optionality as typed state before reaching this layer.
    OPTIONAL = optionalBoundaryFile()

    // Determine if (re)alignment is required for input BAM
    bam_channel = ingress(
        ref,
        ref_index,
        params.bam,
        ingress_ext,
    )
    | map { xam, xai, meta -> [xam, xai, withStableIdentity(meta, params)] }

    reference_compatibility = referenceCompatibilityRequirements(params)

    // Check the genome build once for all branches that need restricted
    // reference compatibility. Bounded entries should record the equivalent
    // state through gnostikon-workflow-control.
    if (reference_compatibility.requires_validation) {
        genome_build = validateReferenceCompatibility(
            bam_channel,
            Channel.value(reference_compatibility.required_by.join(",")),
            Channel.value(reference_compatibility.requires_hg38)
        )
    }
    else {
        genome_build = null
    }

    // Check for contamination, if MT is present.
    if (params.haplocheck){
        // First, let's get the mitogenome code.
        if (params.mitogenome){
            // Ensure that the given chromosome code is in the reference genome
            mt_code = ref_index
            | splitCsv(sep:'\t', header: false)
            | map{ it[0] }
            | filter{it == params.mitogenome}
            | ifEmpty{
                throw new Exception(colors.red + "Mitochondrial genome ${params.mitogenome} not present in the reference." + colors.reset)
            }
        } else {
            default_mt_codes = Channel.of(['chrM', 'Mt', 'MT']) | flatten
            mt_code = ref_index
            | splitCsv(sep:'\t', header: false)
            | map{ it[0] }
            | cross(default_mt_codes)
            | map{it[0]}
        }
        // Do not run if there are multiple mitochondrial codes.
        n_mt_codes = mt_code
        | count
        | subscribe {
            if (it != 1){
                throw new Exception(colors.red + "Unexpected number of mitochondrial chromosome found: ${it}." + colors.reset) 
            }
        }
        hap_check_result = haplocheck(bam_channel, ref_channel.collect(), mt_code)
        hap_check = hap_check_result
        | ifEmpty{
            log.warn "Haplocheck failed to run. The workflow will continue, but will not output a contamination determination."
            optionalBoundaryFile()
        }
        hap_check_publish = hap_check_result
    } else {
        // If haplocheck is not needed, use the predefined boundary empty file.
        hap_check = optionalBoundaryChannel()
        hap_check_publish = Channel.empty()
    }

    // Set BED (and create the default all chrom BED if necessary)
    // Make a second bed channel that won't be filtered based on coverage,
    // to be used as a final ROI filter
    bed = null
    using_user_bed = false

    if(params.bed){
        using_user_bed = true
        // Sanitise the input BED file
        input_bed = Channel.fromPath(params.bed, checkIfExists: true)

        bed = sanitise_bed(input_bed, ref_channel)
        roi_filter_bed = bed
    }
    else {
        bed = getAllChromosomesBed(ref_channel).all_chromosomes_bed
    }

    // Set coverage_bed, used only to generate coverage metrics
    coverage_bed = null
    if (params.coverage_bed) {
        // Sanitise the coverage BED file
        input_coverage_bed = Channel.fromPath(params.coverage_bed, checkIfExists: true)

        coverage_bed = sanitise_coverage_bed(input_coverage_bed, ref_channel)

    }
    else {
        coverage_bed = Channel.empty()
    }

    // mosdepth for depth traces -- passed into wf-snp :/

    mosdepth_input(bam_channel, bed, ref_channel, params.depth_window_size, create_bed_summary, "bed")
    mosdepth_stats = mosdepth_input.out.mosdepth_tuple
    mosdepth_summary = mosdepth_input.out.summary
    if (params.depth_intervals){
        mosdepth_perbase = mosdepth_input.out.perbase
    } else {
        mosdepth_perbase = Channel.empty()
    }
    

    if (create_bed_summary){
        bed_summary = mosdepth_input.out.bed_summary
    }
    else {
        bed_summary = Channel.empty()
    }

    // if requested, run mosdepth again to generate coverage summary for `--coverage_bed`
    if (create_coverage_bed_summary){
        mosdepth_coverage(bam_channel, coverage_bed, ref_channel, params.depth_window_size, create_coverage_bed_summary, "coverage_bed")
        coverage_bed_summary = mosdepth_coverage.out.bed_summary
    }
    else {
        coverage_bed_summary = Channel.empty()
    }

    // Determine if the coverage threshold is met to perform analysis.
    // If too low, it creates an empty input channel, 
    // avoiding the subsequent processes to do anything
    software_versions = getVersions()
    workflow_params = getParams()
    if (params.bam_min_coverage > 0){
        if (params.bed){
            // Filter out the data based on the individual region's coverage
            coverage_check = get_region_coverage(bed, mosdepth_stats)
            bed = coverage_check.filt_bed
            mosdepth_stats = coverage_check.mosdepth_tuple
        }
    } 
    bam_channel.set{pass_bam_channel}
    discarded_bams = Channel.empty()

    // Check and perform downsampling if needed.
    if (params.downsample_coverage){
        // Define per-sample reduction rates from the sample's mosdepth output.
        downsampling_summary = mosdepth_input.out.summary
            | map { summary -> [summary.name.replace(".mosdepth.summary.txt", ""), summary] }
        downsampling_bams = pass_bam_channel
            | map { xam, xai, meta -> [meta.alias, xam, xai, meta] }
        if (params.bed) {
            downsampling_regions = mosdepth_stats
                | map { meta, regions, dists, thresholds -> [meta.alias, regions] }
            downsampling_eval_input = downsampling_summary
                .join(downsampling_bams, by: 0)
                .join(downsampling_regions, by: 0)
                .map { alias, summary, xam, xai, meta, regions -> [meta, summary, regions] }
        } else {
            downsampling_eval_input = downsampling_summary
                .join(downsampling_bams, by: 0)
                .map { alias, summary, xam, xai, meta -> [meta, summary] }
        }
        if (params.bed) {
            downsampling_ratio = eval_downsampling(downsampling_eval_input).downsampling_ratio
        } else {
            downsampling_ratio = eval_downsampling_without_bed(downsampling_eval_input).downsampling_ratio
        }
        downsampling_ratio
            .branch{
                sample_id, meta, to_downsample, downsampling_rate ->
                subset: to_downsample == 'true'
                ready: to_downsample == 'false'
            }
            .set{ratio}

        // Define extension based on whether we are asking for CNV. If so,
        // use BAM, otherwise use what the user wants.
        downsampling_input = pass_bam_channel
            .map { xam, xai, meta -> [meta.sample_id, xam, xai, meta] }
            .join(ratio.subset, by: 0)
            .map { sample_id, xam, xai, meta, ratio_meta, to_downsample, downsampling_rate ->
                def downsampling_ext = convert_cram_to_bam ? ['bam', 'bai'] : desired_xam_ext
                [xam, xai, meta, to_downsample, downsampling_rate, downsampling_ext[0], downsampling_ext[1]]
            }
        downsampling(downsampling_input, ref_channel)

        // prepare ready files
        pass_bam_channel
            .map { xam, xai, meta -> [meta.sample_id, xam, xai, meta] }
            .join(ratio.ready, by: 0)
            .map{ sample_id, xam, xai, meta, ratio_meta, to_downsample, downsampling_rate -> [xam, xai, meta]}
            .branch{
                xam, xai, meta ->
                cram: xam.name.endsWith('.cram')
                bam: xam.name.endsWith('.bam')
            }
            .set{branched_bam_channel}

        // Convert aligned CRAMs that could not be downsampled to BAM if needed and mix with other ingested BAMs
        // Avoid issues with BAM being passed to `cram_to_bam`.
        ready_bam_channel = cram_to_bam(
            branched_bam_channel.cram,
            ref_channel.map { ref, index, cache, path -> [ref, index] }
        )
        | map { xam, xai, meta -> [xam, xai, meta + [output: false, is_cram: false]] }
        | mix(branched_bam_channel.bam)


        // Merge downsampled and ready BAMs by stable sample identity.
        downsampled_bam_keyed = downsampling.out.xam
            .map { xam, xai, meta -> [meta.sample_id, xam, xai, meta] }
        ready_bam_keyed = ready_bam_channel
            .map { xam, xai, meta -> [meta.sample_id, xam, xai, meta] }
        downsampled_bam_keyed
            .join(ready_bam_keyed, by: 0, remainder: true)
            .filter{ row -> row[1] != null && row[4] != null }
            .subscribe{
                throw new Exception(colors.red + "Unexpected channel size when merging." + colors.reset) 
            }
        // If this passes, then we can create the proper channel.
        downsampled_bam_keyed
            .join(ready_bam_keyed, by: 0, remainder: true)
            .map { row ->
                row[1] != null ? [row[1], row[2], row[3]] : [row[4], row[5], row[6]]
            }
            .set{pass_bam_channel}

        // Prepare the output files for mosdepth.
        // First, we compute the depth for the downsampled files, if it
        // exists 
        mosdepth_downsampled(downsampling.out, bed, ref_channel, params.depth_window_size, false, "bed")
        // Then, choose which output will be used for downstream coverage/QC.
        // If it needs to be subset, then the combined output exists, whereas 
        // the original mosdepth file is merged with the empty ready channel, leaving 
        // the correct file to output. Otherwise, the reverse happens and it emits 
        // the original mosdepth files. 
        ratio_subset_alias = ratio.subset
            .map { sample_id, meta, to_downsample, downsampling_rate -> [meta.alias, true] }
        ratio_ready_alias = ratio.ready
            .map { sample_id, meta, to_downsample, downsampling_rate -> [meta.alias, true] }

        mosdepth_summary =
            mosdepth_downsampled.out.summary
                .map { summary -> [summary.name.replace(".mosdepth.summary.txt", ""), summary] }
                .join(ratio_subset_alias, by: 0)
                .map { alias, summary, marker -> summary }
                .mix(
                    mosdepth_input.out.summary
                        .map { summary -> [summary.name.replace(".mosdepth.summary.txt", ""), summary] }
                        .join(ratio_ready_alias, by: 0)
                        .map { alias, summary, marker -> summary }
                )
        mosdepth_stats =
            mosdepth_downsampled.out.mosdepth_tuple
                .map { meta, regions, dists, thresholds -> [meta.alias, meta, regions, dists, thresholds] }
                .join(ratio_subset_alias, by: 0)
                .map { alias, meta, regions, dists, thresholds, marker -> [meta, regions, dists, thresholds] }
                .mix(
                    mosdepth_input.out.mosdepth_tuple
                        .map { meta, regions, dists, thresholds -> [meta.alias, meta, regions, dists, thresholds] }
                        .join(ratio_ready_alias, by: 0)
                        .map { alias, meta, regions, dists, thresholds, marker -> [meta, regions, dists, thresholds] }
                )
        if (params.depth_intervals){
            mosdepth_perbase =
                mosdepth_downsampled.out.perbase
                    .map { perbase -> [perbase.name.replace(".per-base.bedgraph.gz", ""), perbase] }
                    .join(ratio_subset_alias, by: 0)
                    .map { alias, perbase, marker -> perbase }
                    .mix(
                        mosdepth_input.out.perbase
                            .map { perbase -> [perbase.name.replace(".per-base.bedgraph.gz", ""), perbase] }
                            .join(ratio_ready_alias, by: 0)
                            .map { alias, perbase, marker -> perbase }
                    )
        } else {
            mosdepth_perbase = Channel.empty()
        }
    }

    // TODO downsampling should be incorporated to ingress to avoid
    //      call to bootleg readStats here
    // Run readStats depending on the downsampling, if requested.
    // Also check if using_user_bed is true, in which case pass the sanitised 
    // BED to readStats, rather than the filtered BED
    if (params.downsample_coverage) {
        readStats(
            pass_bam_channel,
            using_user_bed ? roi_filter_bed : bed,
            ref_channel
        )
    } else {
        readStats(
            bam_channel,
            using_user_bed ? roi_filter_bed : bed,
            ref_channel
        )
    }
    bam_stats = readStats.out.read_stats
    bam_flag = readStats.out.flagstat
    bam_hists = readStats.out.histograms
    // Keep run IDs as per-sample artefacts. Controller-owned manifest/event
    // projection replaces the inherited params.wf runtime mutation.
    bam_runids = readStats.out.runids
    bam_basecallers = readStats.out.basecallers

    // Define per-sample depth_pass channel.
    if (params.bam_min_coverage > 0){
        // If bam_min_coverage is > 0, then check the coverage
        if (params.bed){
            summary_for_coverage = mosdepth_summary
                | map { summary -> [summary.name.replace(".mosdepth.summary.txt", ""), summary] }
            bam_for_coverage = pass_bam_channel
                | map { bam, bai, meta -> [meta.alias, bam, bai, meta] }
            regions_for_coverage = mosdepth_stats
                | map { meta, regions, dists, thresholds -> [meta.alias, regions] }
            coverage_eval_input = summary_for_coverage
                .join(bam_for_coverage, by: 0)
                .join(regions_for_coverage, by: 0)
                .map { alias, summary, bam, bai, meta, regions -> [meta, summary, regions] }
            depth_pass = evaluateCoveragePass(coverage_eval_input, params.bam_min_coverage).coverage_state

        // Without a BED, use summary values for the region
        } else {
            summary_for_coverage = mosdepth_summary
                | map { summary -> [summary.name.replace(".mosdepth.summary.txt", ""), summary] }
            bam_for_coverage = pass_bam_channel
                | map { bam, bai, meta -> [meta.alias, bam, bai, meta] }
            coverage_eval_input = summary_for_coverage
                .join(bam_for_coverage, by: 0)
                .map { alias, summary, bam, bai, meta -> [meta, summary] }
            depth_pass = evaluateCoveragePassWholeGenome(coverage_eval_input, params.bam_min_coverage).coverage_state
        }
    } else {
        // Otherwise, set all BAM to pass.
        depth_pass = bam_channel
            | map{ bam, bai, meta -> [meta.sample_id, 'true', null, 1] }
    }


    // Implement the BAM stats barrier after the pre-processing.
    // This will use the reads after the downsampling when requested.
    // Currently, it works using only the BAM coverage, but in the
    // future will allow to easily implement additional thresholds.
    pass_bam_keyed = pass_bam_channel
        | map { bam, bai, meta -> [meta.sample_id, bam, bai, meta] }
    filter = depth_pass
        .combine(pass_bam_keyed, by: 0)
        .branch{
            sample_id, dp_pass, dp_val_env, region_count, bam, bai, meta ->
            pass: dp_pass == 'true' && meta.has_mapped_reads
            not_pass: true
            }
    // Create the pass_bam_channel  channel when they pass
    filter.pass
        .map{it ->
            it.size > 0 ? [it[-3], it[-2], it[-1]] : it
        }
        .set{pass_bam_channel}

    // If it doesn't pass the minimum depth required, 
    // emit a bam channel of discarded bam files.
    filter.not_pass
        .subscribe {
            sample_id, dp_pass, dp, region_count, bam, bai, meta ->
            // check where it failed
            def fail_depth_reason = !meta.has_mapped_reads ? "no mapped reads" : (dp as float) < params.bam_min_coverage ? "depth: ${dp} < ${params.bam_min_coverage}" : "no covered target regions"
            // Raise the alarm explicitly; per-sample state must still reflect the rejected sample.
            String fail_depth_msg = """\
            ################################################################################
            # INPUT DATA PROBLEM: rejected_low_coverage
            An input file has insufficient coverage for analysis and will not be processed
            by the workflow:

            ${bam.getName()} has ${fail_depth_reason}
            Sample state: rejected_low_coverage
            ################################################################################
            """.stripIndent()
            log.error fail_depth_msg
        }
    filter.not_pass
        .map{it ->
            it.size > 0 ? [it[-3], it[-2], it[-1]] : it
        }
        .set{discarded_bams}

    // Set biological sex to the user-provided sex if given
    // Otherwise, attempt to infer if genome_build is set (as we're likely going to need it)
    // NOTE You may feel compelled to add sex to the bam channel meta but then
    //      this will block any downstream access to the bam channel on infer_sex!
    if (params.sex) {
        sex = Channel.of(params.sex)
    }
    else if (genome_build) {
        log.warn "Inferring genetic sex of sample as params.sex was not provided."
        sex = infer_sex(mosdepth_summary)
    }
    else {
        sex = Channel.of(null)
    }

    rejected_low_coverage_status = discarded_bams
        .map{ bam, bai, meta -> tuple(bam, meta) }
        | rejectedLowCoverage

    // Set up BED for wf-human-snp, wf-human-str or run_haplotagging
    // CW-2383: we first call the SNPs to generate an haplotagged bam file for downstream analyses
    if (run_snp) {
        if(using_user_bed) {
            snp_bed = bed
        }
        else {
            // wf-human-snp still consumes an explicit boundary empty BED.
            snp_bed = optionalBoundaryChannel()
        }

        if(params.clair3_model_path) {
            log.warn "Overriding Clair3 model with ${params.clair3_model_path}."
            clair3_model = Channel.fromPath(params.clair3_model_path, type: "dir", checkIfExists: true)
        }
        else {
            // Add back basecaller models, if available.
            // Combine each BAM channel with the appropriate basecaller file
            // Fetch the unique basecaller models and, if these are more than the
            // ones in the metadata, add them in there.
            // We do it in the snv scope as it is the only workflow relying on the
            // model, and given it has to wait for the readStats process, we try
            // minimizing the waits
            detect_basecall_model(pass_bam_channel, bam_basecallers)
            basecaller_cfg = detect_basecall_model.out.basecaller_cfg
            pass_bam_channel = detect_basecall_model.out.bam_channel

            // Get Clair3 model
            clair3_model = lookup_clair3_model(
                Channel.fromPath("${projectDir}/data/clair3_models.tsv", checkIfExists: true),
                basecaller_cfg
            )
            | map {
                log.info "Autoselected Clair3 model: ${it[0]}" // use model name for log message
                it[1] // then just return the path to match the interface above
            }
        }

        clair_vcf = snp(
            pass_bam_channel,
            snp_bed,
            ref_channel,
            clair3_model,
            genome_build,
            haplotagged_output_fmt,
            run_haplotagging,
            using_user_bed,
            chromosome_codes
        )
    }
    
    // wf-human-sv
    // CW-2383: we then call SVs using either the pass bam or haplotagged bam, depending on the settings
    if(params.sv) {
        // If haplotagged bam is available and phase_snv is required, then phase.
        // Otherwise, use pass_bam_file (passing a haplotagged bam and not requiring phase_snv would
        // cause the workflow to wait for the tagged reads, but not enable phasing of sv since --phase 
        // won't be set; hence skip it if not required).
        if (run_haplotagging){
            sv_bam = clair_vcf.haplotagged_xam
        } else {
            sv_bam = pass_bam_channel
        }
        results_sv = sv(
            sv_bam,
            ref_channel,
            bed,
            mosdepth_input.out.summary,
            OPTIONAL,
            genome_build,
            chromosome_codes,
            workflow_params
        )
        artifacts = results_sv.output.flatten()
        sniffles_vcf = results_sv.sniffles_vcf
        json_sv = results_sv.sv_stats_json
        sv_vcf = results_sv.for_phasing
        output_sv(artifacts)
    } else {
        json_sv = Channel.empty()
        sv_vcf = Channel.empty()
        sniffles_vcf = Channel.empty()
    }

    // Then, we finish working on the SNPs by refining with SVs and annotating them. This is needed to
    // maximise the interaction between Clair3 and Sniffles.
    if (run_snp){
        // Channel of results.
        // We drop the raw .vcf(.tbi) file from Clair3 in it to then add back the files in the 
        // snp_vcf channel, allowing for the latest file to be emitted.
        // Channel structure is
        /*  [
        *   [CRAM, CRAI]
        *   [vcf, tbi]
        *   [gvcf, tbi] (optional)
        *   haploblocks (optional)
         ] */
        // If first element ends with .vcf.gz, then discard it
        clair_vcf.clair3_results
            .filter{
                !it[0].name.endsWith('.vcf.gz')
            }
            .collect()
            .set{clair3_results}

        // Define which bam to use for final refinement
        if (run_haplotagging){
            snp_refinement_xam = clair_vcf.haplotagged_xam
        } else {
            snp_refinement_xam = pass_bam_channel
        }

        // Refine the SNP phase using SVs from Sniffles
        if (params.refine_snp_with_sv && params.sv){
            // Run by chromosome to reduce memory usage
            // Use collect on the reference, the SNP VCF
            // and the SV VCFs to ensure running on each contig. 
            refined_snps = refine_with_sv(
                ref_channel.collect(),
                clair_vcf.vcf_files.combine(clair_vcf.contigs),
                snp_refinement_xam | first,
                sniffles_vcf.map{meta, vcf -> vcf}.collect()
            )
            final_snp_vcf = concat_refined_snp(
                refined_snps.map{ meta, vcf, tbi -> [meta, vcf]}.groupTuple(),
                "wf_snp"
            )
        } else {
            // If refine_with_sv not requested, passthrough
            final_snp_vcf = clair_vcf.vcf_files
        }

        // Filter by BED, if provided
        if (params.bed) {
            final_snp_vcf_filtered = bed_filter(final_snp_vcf, roi_filter_bed, "snp", "vcf").filtered
        }
        else {
            final_snp_vcf_filtered = final_snp_vcf
        }

        // Run annotation, when requested.
        if (!params.annotation) {
            snp_vcf = final_snp_vcf_filtered
            clinvar_vcf = Channel.fromPath("${projectDir}/data/empty_clinvar.vcf")
        }
        else {
            // do annotation and publish the ClinVar-filtered variant list
            // snpeff is slow so we'll just pass the whole VCF but annotate per contig
            annotations = annotate_snp_vcf(
                final_snp_vcf_filtered.combine(clair_vcf.contigs), genome_build.first(), "snp"
            )
            snp_vcf = concat_snp_vcfs(annotations.map{ meta, vcf, tbi -> [meta,vcf]}.groupTuple(), "wf_snp").final_vcf
            
            sift_clinvar_snp_vcf(snp_vcf, genome_build, "snp")
            clinvar_vcf = sift_clinvar_snp_vcf.out.final_vcf_clinvar.map{ vcf, tbi -> vcf }
        }

        // Run vcf statistics on the final VCF file
        vcf_stats = vcfStats(snp_vcf)

        snp_metrics = snp_stats(vcf_stats)
        json_snp = snp_metrics.snp_stats_json

        // Output for SNP
        Channel.empty()
            .concat(clair3_results)
            .concat(snp_vcf.map{meta, vcf, tbi -> [vcf, tbi]})
            .flatten() | output_snp
    } else {
        json_snp = Channel.empty()
        snp_vcf = Channel.empty()
    }

    // wf-human-mod
    // Validate modified bam
    if (params.mod){
        // Perform validation on the initial BAM, to allow running on the
        // fragmented BAMs when phasing is required
        validate_modbam(pass_bam_channel, ref_channel)

        // Warn of input without modified base tags
        validate_modbam.out.branch{
            stdbam: it[-1] == '65'
            modbam: it[-1] == '0'
            }.set{validated_modbam}
        // Log warn if it is not modbam
        validated_modbam.stdbam.subscribe{
            it -> log.warn "Input ${it[0]} does not contain modified base tags. Was a modified basecalling model selected when basecalling this data?"
        }
        modbam_ch = validated_modbam.modbam
                .map{cram, crai, meta, code -> [cram, crai, meta]}

        // Compute the probabilities on the valid modbam
        modkit_probs = sample_probs(modbam_ch, ref_channel)

        // Save the other as input, keeping only the necessary elements
        if (run_haplotagging){
            modkit_bam = clair_vcf.str_bams
        } else {
            modkit_bam = modbam_ch
        }

        // If the input is not modBAM, the workflow won't process anything because the
        // filtering probabilities are not calculated, preventing downstream processes.
        results = mod(
            modkit_bam,  // Input BAM for modkit
            bam_flag,  // Flagstats used to define chromosomes to analyse
            chromosome_codes,  // Accepted chromosome codes for the human genome
            modkit_probs,  // modkit probabilities for filtering
            ref_channel,
            run_haplotagging  // Define if the data are haplotagged.
        )
        mod_bedmethyl = results.bedmethyl
    } else {
        mod_bedmethyl = Channel.empty()
    }

    // wf-human-cnv
    if (params.cnv) {
        // cnv calling with qdnaseq
        if (params.use_qdnaseq) {
            results_cnv = cnv_qdnaseq(
                pass_bam_channel,
                bam_stats,
                genome_build,
                workflow_params
            )
        // cnv calling with spectre
        } else {
            results_cnv = cnv_spectre(
                pass_bam_channel,
                ref_channel,
                clair_vcf.vcf_files,
                bed,
                genome_build,
                workflow_params
            )
        }
        cnv_vcf = results_cnv.cnv_vcf
        output_cnv(results_cnv.output)
    } else {
        cnv_vcf = Channel.empty()
    }

    // wf-human-str
    if (params.str) {
        // use haplotagged bam from snp() as input to str()
        bam_channel_str = clair_vcf.str_bams

        results_str = str_compat(
          bam_channel_str,
          ref_channel,
          bam_stats,
          sex,
          workflow_params
        )
        str_vcf = results_str.str_vcf
        output_str(results_str.output)
    } else {
        str_vcf = Channel.empty()
    }

    // Combine into a final JSON of analyses stats
    analyses_jsons = Channel.empty()
        | mix(
            json_snp,
            json_sv
        )
        | collect
        | ifEmpty(OPTIONAL)

    final_json = combine_metrics_json(
        analyses_jsons,
        bam_flag,
        bam_hists,
        mosdepth_stats,
        mosdepth_summary,
        hap_check,
        sex,
    )

    // If the workflow is set to run for the partner, then execute the merging
    if (run_partners){
        partners(
            snp_vcf,
            sv_vcf,
            cnv_vcf,
            str_vcf,
            pass_bam_channel,
            run_haplotagging
        )
    }

    publish_artifact(
        // emit bams with the "to_align" meta tag
        // but only if haplotagging is not on
        // drop meta which otherwise creates a spurious input.1 file
        bam_channel
        | filter( { it[2].to_align && !run_haplotagging} )
        | map { xam, xai, meta -> [xam, xai] }
        | mix(
            bam_stats.flatten(),
            bam_flag.flatten(),
            bam_runids.flatten(),
            mosdepth_stats.map{ meta, bed, dist, threshold -> [bed, dist, threshold]}.flatten(),
            mosdepth_summary.flatten(),
            mosdepth_perbase.flatten(),
            mod_bedmethyl.flatten(),
            final_json.flatten(),
            bed_summary.flatten(),
            coverage_bed_summary.flatten(),
            hap_check_publish.flatten()
        )
    )

}
