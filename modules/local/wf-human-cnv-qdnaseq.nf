// fix_vcf was unglued to avoid installing base deps in CNV container
process callCNV {
    label "wf_cnv"
    cpus 1
    memory { 16.GB * task.attempt }
    maxRetries 1
    errorStrategy {task.exitStatus in [137,140] ? 'retry' : 'finish'}
    input:
        tuple path(bam), path(bai), val(xam_meta)
        val(genome_build)
    output:
        tuple val(xam_meta), path("${xam_meta.alias}.wf_cnv.vcf.gz"), path("${xam_meta.alias}.wf_cnv.vcf.gz.tbi"), emit: cnv_vcf
    script:
        """
        run_qdnaseq.r --bam ${bam} --out_prefix ${xam_meta.alias} --binsize ${params.qdnaseq_bin_size} --reference ${genome_build}
        cut -f5 ${xam_meta.alias}_calls.bed | paste ${xam_meta.alias}_bins.bed - > ${xam_meta.alias}_combined.bed

        # Fix known QDNAseq VCF malformations
        mv ${xam_meta.alias}_calls.vcf raw.vcf
        mv ${xam_meta.alias}_segs.vcf raw_segs.vcf
        fix_qdnaseq_vcf.py -i raw.vcf -o ${xam_meta.alias}.wf_cnv.vcf --sample_id ${xam_meta.alias}
        fix_qdnaseq_vcf.py -i raw_segs.vcf -o ${xam_meta.alias}_segs.vcf --sample_id ${xam_meta.alias}

        # bgzip and index calls VCF
        bgzip ${xam_meta.alias}.wf_cnv.vcf
        tabix -f -p vcf ${xam_meta.alias}.wf_cnv.vcf.gz
        """
}

