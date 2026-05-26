import groovy.json.JsonOutput

/*
 * Helpers for controller-launched bounded entries.
 *
 * These helpers validate the params file written by gnostikon-workflow-control
 * before a bounded entry starts doing work. They are intentionally separate
 * from the legacy main.nf compatibility validation path.
 */

def _requiredBoundedParam(params, String name) {
    def value = params[name]
    if (value == null || value.toString().trim() == "") {
        throw new IllegalArgumentException("bounded entry requires controller param '${name}'")
    }
    return value.toString()
}

def _boundedOutputPaths(def raw) {
    if (!(raw instanceof Map) || raw.isEmpty()) {
        throw new IllegalArgumentException("bounded entry requires non-empty controller param 'output_paths'")
    }
    return raw.collectEntries { key, value ->
        if (value == null || value.toString().trim() == "") {
            throw new IllegalArgumentException("bounded output path '${key}' is empty")
        }
        [(key.toString()): value.toString()]
    }.sort()
}

def _requireOutputPaths(Map outputPaths, Set expected) {
    if (outputPaths.keySet() != expected) {
        def missing = (expected - outputPaths.keySet()).sort()
        def unexpected = (outputPaths.keySet() - expected).sort()
        throw new IllegalArgumentException(
            "bounded entry output_paths mismatch; missing=${missing.join(',') ?: 'none'} " +
            "unexpected=${unexpected.join(',') ?: 'none'}"
        )
    }
    return outputPaths
}

def _choice(String name, String value, Set allowed) {
    if (!allowed.contains(value)) {
        throw new IllegalArgumentException(
            "bounded entry param '${name}' must be one of ${allowed.sort().join(', ')}; received '${value}'"
        )
    }
    return value
}

def _optionalBoundedParam(params, String name, String defaultValue) {
    def value = params[name]
    if (value == null || value.toString().trim() == "") {
        return defaultValue
    }
    return value.toString()
}

def _mappingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "minimap2_preset",
        "cap_kalloc",
        "cap_sw_mem",
        "fastq_threads",
        "map_threads",
        "sort_threads",
        "bamstats_threads",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported mapping option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("mapping option '${name}' must be >= 1")
        }
        return number
    }
    return [
        minimap2_preset: (options.minimap2_preset ?: "lr:hq").toString(),
        cap_kalloc: (options.cap_kalloc ?: "100m").toString(),
        cap_sw_mem: (options.cap_sw_mem ?: "50m").toString(),
        fastq_threads: positiveInt("fastq_threads", 1),
        map_threads: positiveInt("map_threads", 4),
        sort_threads: positiveInt("sort_threads", 2),
        bamstats_threads: positiveInt("bamstats_threads", 2),
    ]
}

def _sampleAggregationOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "view_threads",
        "bamstats_threads",
        "mosdepth_threads",
        "coverage_min_depth",
        "depth_window_size",
        "mosdepth_thresholds",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported sample aggregation option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("sample aggregation option '${name}' must be >= 1")
        }
        return number
    }
    def nonNegativeNumber = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as BigDecimal
        if (number < 0) {
            throw new IllegalArgumentException("sample aggregation option '${name}' must be >= 0")
        }
        return number
    }
    return [
        view_threads: positiveInt("view_threads", 2),
        bamstats_threads: positiveInt("bamstats_threads", 2),
        mosdepth_threads: positiveInt("mosdepth_threads", 2),
        coverage_min_depth: nonNegativeNumber("coverage_min_depth", 0),
        depth_window_size: positiveInt("depth_window_size", 500),
        mosdepth_thresholds: (options.mosdepth_thresholds ?: "1,10,15,20,30").toString(),
    ]
}

def _variantCallingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "chunk_num",
        "chunk_size",
        "min_qual",
        "var_pct_full",
        "ref_pct_full",
        "snp_min_af",
        "indel_min_af",
        "min_contig_size",
        "ctg_name",
        "include_all_ctgs",
        "emit_gvcf",
        "target_bed",
        "genotyping_vcf",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported variant calling option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("variant calling option '${name}' must be >= 1")
        }
        return number
    }
    def nonNegativeInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 0) {
            throw new IllegalArgumentException("variant calling option '${name}' must be >= 0")
        }
        return number
    }
    def nonNegativeNumber = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as BigDecimal
        if (number < 0) {
            throw new IllegalArgumentException("variant calling option '${name}' must be >= 0")
        }
        return number
    }
    return [
        threads: positiveInt("threads", 4),
        chunk_num: nonNegativeInt("chunk_num", 0),
        chunk_size: positiveInt("chunk_size", 5000000),
        min_qual: nonNegativeNumber("min_qual", 2),
        var_pct_full: nonNegativeNumber("var_pct_full", 0.7),
        ref_pct_full: nonNegativeNumber("ref_pct_full", 0.1),
        snp_min_af: nonNegativeNumber("snp_min_af", 0.08),
        indel_min_af: nonNegativeNumber("indel_min_af", 0.15),
        min_contig_size: nonNegativeInt("min_contig_size", 0),
        ctg_name: (options.ctg_name ?: "").toString(),
        include_all_ctgs: options.containsKey("include_all_ctgs") ? options.include_all_ctgs as Boolean : false,
        emit_gvcf: options.containsKey("emit_gvcf") ? options.emit_gvcf as Boolean : false,
        target_bed: (options.target_bed ?: "").toString(),
        genotyping_vcf: (options.genotyping_vcf ?: "").toString(),
    ]
}

def _structuralVariantOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "cluster_merge_pos",
        "min_sv_length",
        "min_read_support",
        "min_read_support_limit",
        "include_all_ctgs",
        "chromosome_codes",
        "tandem_repeats_bed",
        "genome_build",
        "sniffles_options",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported structural variant option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("structural variant option '${name}' must be >= 1")
        }
        return number
    }
    def nonNegativeInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 0) {
            throw new IllegalArgumentException("structural variant option '${name}' must be >= 0")
        }
        return number
    }
    def readSupport = options.containsKey("min_read_support") ? options.min_read_support : "auto"
    if (readSupport.toString() != "auto") {
        def readSupportNumber = readSupport as Integer
        if (readSupportNumber < 0) {
            throw new IllegalArgumentException("structural variant option 'min_read_support' must be 'auto' or >= 0")
        }
        readSupport = readSupportNumber
    }
    def chromosomeCodes = options.chromosome_codes ?: [
        "chr1", "1", "chr2", "2", "chr3", "3", "chr4", "4", "chr5", "5",
        "chr6", "6", "chr7", "7", "chr8", "8", "chr9", "9", "chr10", "10",
        "chr11", "11", "chr12", "12", "chr13", "13", "chr14", "14",
        "chr15", "15", "chr16", "16", "chr17", "17", "chr18", "18",
        "chr19", "19", "chr20", "20", "chr21", "21", "chr22", "22",
        "chrX", "X", "chrY", "Y", "chrM", "M", "chrMT", "MT",
    ]
    if (chromosomeCodes instanceof String) {
        chromosomeCodes = chromosomeCodes.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(chromosomeCodes instanceof Collection) || chromosomeCodes.isEmpty()) {
        throw new IllegalArgumentException("structural variant option 'chromosome_codes' must be a non-empty list or comma-separated string")
    }
    def snifflesOptions = options.sniffles_options instanceof Map ? options.sniffles_options : [:]
    def snifflesAllowed = ["mosaic", "min_support", "minsvlen"] as Set
    def unexpectedSniffles = snifflesOptions.keySet().collect { it.toString() }.findAll { !snifflesAllowed.contains(it) }.sort()
    if (unexpectedSniffles) {
        throw new IllegalArgumentException("unsupported Sniffles option(s): ${unexpectedSniffles.join(', ')}")
    }
    if (snifflesOptions.containsKey("minsvlen") && options.containsKey("min_sv_length")) {
        throw new IllegalArgumentException("structural variant option 'min_sv_length' and sniffles_options.minsvlen cannot both be set")
    }
    return [
        threads: positiveInt("threads", 4),
        cluster_merge_pos: nonNegativeInt("cluster_merge_pos", 150),
        min_sv_length: nonNegativeInt("min_sv_length", 30),
        min_read_support: readSupport,
        min_read_support_limit: nonNegativeInt("min_read_support_limit", 2),
        include_all_ctgs: options.containsKey("include_all_ctgs") ? options.include_all_ctgs as Boolean : false,
        chromosome_codes: chromosomeCodes.collect { it.toString() },
        tandem_repeats_bed: (options.tandem_repeats_bed ?: "").toString(),
        genome_build: (options.genome_build ?: "").toString(),
        sniffles_options: snifflesOptions,
    ]
}

def boundedEntryParams(params, String expectedFamily, String entryName) {
    def task_family = _requiredBoundedParam(params, "task_family")
    if (task_family != expectedFamily) {
        throw new IllegalArgumentException(
            "bounded entry '${entryName}' expected task_family '${expectedFamily}' but received '${task_family}'"
        )
    }
    return [
        entry_schema: "wf-human-variation.bounded_entry.v1",
        entry_name: entryName,
        task_family: task_family,
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        output_paths: _boundedOutputPaths(params.output_paths),
    ]
}

def boundedMappingEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "mapped_xam",
            "mapped_xam_index",
            "alignment_metadata",
            "run_ids",
            "mapper_provenance",
            "qc_stats",
        ] as Set
    )
    def mapper = _choice("mapper", _optionalBoundedParam(params, "mapper", "minimap2"), ["minimap2"] as Set)
    def input_kind = _choice(
        "input_kind",
        _requiredBoundedParam(params, "input_kind"),
        ["bam", "cram", "ubam", "basecalled_bam"] as Set
    )
    def output_format = _choice(
        "output_format",
        _optionalBoundedParam(params, "output_format", "bam"),
        ["bam", "cram"] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_mapping.v1",
        entry_name: "mapping",
        task_family: _choice("task_family", _requiredBoundedParam(params, "task_family"), ["mapping"] as Set),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        input_xam: _requiredBoundedParam(params, "input_xam"),
        input_kind: input_kind,
        input_digest: _requiredBoundedParam(params, "input_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        mapper: mapper,
        mapper_options: _mappingOptions(params.mapper_options),
        mapper_options_digest: _requiredBoundedParam(params, "mapper_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        output_format: output_format,
        output_index_format: output_format == "cram" ? "crai" : "bai",
        output_paths: output_paths,
    ]
}

def boundedSampleAggregationEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "aggregate_xam",
            "aggregate_xam_index",
            "readstats",
            "flagstat",
            "run_ids",
            "basecallers",
            "mosdepth_summary",
            "mosdepth_regions",
            "mosdepth_distribution",
            "mosdepth_thresholds",
            "coverage_state",
            "qc_stats",
            "aggregation_manifest",
        ] as Set
    )
    def output_format = _choice(
        "output_format",
        _optionalBoundedParam(params, "output_format", "bam"),
        ["bam", "cram"] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_sample_aggregation.v1",
        entry_name: "sample_aggregation",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["sample_aggregation"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        mapped_xam: _requiredBoundedParam(params, "mapped_xam"),
        mapped_xam_index: _requiredBoundedParam(params, "mapped_xam_index"),
        mapped_xam_digest: _requiredBoundedParam(params, "mapped_xam_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        aggregation_config_digest: _requiredBoundedParam(params, "aggregation_config_digest"),
        coverage_config_digest: _requiredBoundedParam(params, "coverage_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        output_format: output_format,
        output_index_format: output_format == "cram" ? "crai" : "bai",
        aggregation_options: _sampleAggregationOptions(params.aggregation_options),
        output_paths: output_paths,
    ]
}

def boundedVariantCallingEntryParams(params) {
    def mode = _choice(
        "variant_mode",
        _requiredBoundedParam(params, "variant_mode"),
        ["snp", "snp_gvcf", "sv"] as Set
    )
    def expected_outputs = ["variant_calling_manifest", "variant_calling_provenance", "qc_stats"] as Set
    if (mode == "sv") {
        expected_outputs += ["structural_variant_vcf", "structural_variant_vcf_index", "structural_variant_snf"] as Set
    }
    else {
        expected_outputs += ["snp_vcf", "snp_vcf_index"] as Set
    }
    if (mode == "snp_gvcf") {
        expected_outputs += ["snp_gvcf", "snp_gvcf_index"] as Set
    }
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def options = _variantCallingOptions(params.variant_options)
    if (mode == "snp_gvcf" && !options.emit_gvcf) {
        throw new IllegalArgumentException("variant_mode 'snp_gvcf' requires variant_options.emit_gvcf=true")
    }
    if (options.target_bed && options.genotyping_vcf) {
        throw new IllegalArgumentException("variant calling options target_bed and genotyping_vcf are mutually exclusive")
    }
    def entry = [
        entry_schema: "wf-human-variation.bounded_variant_calling.v1",
        entry_name: "variant_calling",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["variant_calling"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        aggregate_xam: _requiredBoundedParam(params, "aggregate_xam"),
        aggregate_xam_index: _requiredBoundedParam(params, "aggregate_xam_index"),
        aggregate_xam_digest: _requiredBoundedParam(params, "aggregate_xam_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        variant_mode: mode,
        variant_config_digest: _requiredBoundedParam(params, "variant_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        output_paths: output_paths,
    ]
    if (mode == "sv") {
        entry.mosdepth_summary = _requiredBoundedParam(params, "mosdepth_summary")
        entry.target_bed = _requiredBoundedParam(params, "target_bed")
        entry.structural_variant_options = _structuralVariantOptions(params.structural_variant_options)
    }
    else {
        entry.clair3_model = _requiredBoundedParam(params, "clair3_model")
        entry.clair3_model_digest = _requiredBoundedParam(params, "clair3_model_digest")
        entry.variant_options = options
    }
    return entry
}

def boundedEntryContractJson(Map entry) {
    return JsonOutput.prettyPrint(JsonOutput.toJson(entry))
}
