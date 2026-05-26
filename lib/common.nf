import groovy.json.JsonBuilder

process getParams {
    label "wf_common"
    publishDir "${params.out_dir}", mode: 'copy', pattern: "params.json"
    cache false
    cpus 1
    memory "2 GB"
    output:
        path "params.json"
    script:
        def paramsJSON = new JsonBuilder(params).toPrettyString().replaceAll("'", "'\\\\''")
    """
    # Output nextflow params object to JSON
    echo '$paramsJSON' > params.json
    """
}
