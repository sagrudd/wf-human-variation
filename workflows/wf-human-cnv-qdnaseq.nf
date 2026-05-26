include {
    callCNV;
} from "../modules/local/wf-human-cnv-qdnaseq.nf"


workflow cnv {
    take:
        bam_channel
        read_stats
        genome_build
        workflow_params

    main:

        cnvs = callCNV(bam_channel, genome_build)

    emit:
        output = cnvs.cnv_vcf.map{ meta, vcf, tbi -> [vcf, tbi] }
        cnv_vcf = cnvs.cnv_vcf
}
