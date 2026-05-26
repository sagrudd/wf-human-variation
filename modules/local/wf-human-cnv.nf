include {
    renderToolOptions
} from "../../lib/tool_options.nf"

process callCNV {
    label "spectre"
    cpus 2
    memory 8.GB
    input:
        tuple val(xam_meta), path(vcf), path(vcf_index)
        path("readstats/*")
        tuple path(ref), path(ref_idx), path(ref_cache), env(REF_PATH)
        val(genome_build)
    output:
        tuple val(xam_meta), path("spectre_output/${xam_meta.alias}.vcf"), emit: spectre_vcf
        tuple val(xam_meta), path("spectre_output/${xam_meta.alias}_cnv.bed"), emit: spectre_bed
        tuple val(xam_meta), path("spectre_output/predicted_karyotype.txt"), emit: spectre_karyotype
    script:
        def spectre_args = renderToolOptions("spectre", params.spectre_options, params.spectre_args)
        """
        spectre CNVCaller \
        --bin-size 1000 \
        --coverage readstats/ \
        --sample-id ${xam_meta.alias} \
        --output-dir spectre_output/ \
        --reference ${ref} \
        --blacklist ${genome_build}_blacklist_v1.0 \
        --snv ${vcf} \
        --metadata ${genome_build}_metadata \
        $spectre_args
        """
}

process bgzip_and_index_vcf {
    cpus 1
    input:
        tuple val(xam_meta), path(spectre_vcf)
    output:
        tuple val(xam_meta), path("${xam_meta.alias}.wf_cnv.vcf.gz"), path("${xam_meta.alias}.wf_cnv.vcf.gz.tbi"), emit: spectre_final_vcf
    script:
        """
        bgzip ${spectre_vcf}
        mv ${spectre_vcf}.gz ${xam_meta.alias}.wf_cnv.vcf.gz
        tabix -f -p vcf ${xam_meta.alias}.wf_cnv.vcf.gz
        """
}
