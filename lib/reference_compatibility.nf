def referenceCompatibilityRequirements(params) {
    def required_by = []
    if (params.cnv) {
        required_by += params.use_qdnaseq ? "qdnaseq" : "spectre"
        required_by += "cnv"
    }
    if (params.str) {
        required_by += "str"
    }
    if (params.annotation && (params.snp || params.sv || params.phased || params.cnv)) {
        required_by += "annotation"
    }
    required_by = required_by.unique()
    return [
        required_by: required_by,
        requires_validation: required_by.size() > 0,
        requires_hg38: required_by.contains("str"),
    ]
}
