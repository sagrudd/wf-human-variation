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

def boundedEntryContractJson(Map entry) {
    return JsonOutput.prettyPrint(JsonOutput.toJson(entry))
}
