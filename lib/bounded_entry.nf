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

def _validateTrioRoleSamples(String proband, String father, String mother) {
    def seen = [proband, father, mother] as Set
    if (seen.size() != 3) {
        throw new IllegalArgumentException("trio role sample ids must be distinct")
    }
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

def _clairsToOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "chunk_num",
        "chunk_size",
        "ctg_name",
        "include_all_ctgs",
        "include_germline",
        "indel_min_af",
        "min_bq",
        "min_af",
        "min_coverage",
        "platform",
        "qual",
        "show_ref",
        "debug",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported ClairS-TO option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("ClairS-TO option '${name}' must be >= 1")
        }
        return number
    }
    def nonNegativeInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 0) {
            throw new IllegalArgumentException("ClairS-TO option '${name}' must be >= 0")
        }
        return number
    }
    def nonNegativeNumber = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as BigDecimal
        if (number < 0) {
            throw new IllegalArgumentException("ClairS-TO option '${name}' must be >= 0")
        }
        return number
    }
    def platform = (options.platform ?: "ont").toString()
    if (platform != "ont") {
        throw new IllegalArgumentException("ClairS-TO option 'platform' must be ont")
    }
    return [
        threads: positiveInt("threads", 4),
        chunk_num: nonNegativeInt("chunk_num", 0),
        chunk_size: positiveInt("chunk_size", 5000000),
        ctg_name: (options.ctg_name ?: "").toString(),
        include_all_ctgs: options.containsKey("include_all_ctgs") ? options.include_all_ctgs as Boolean : false,
        include_germline: options.containsKey("include_germline") ? options.include_germline as Boolean : false,
        indel_min_af: nonNegativeNumber("indel_min_af", 0.15),
        min_bq: nonNegativeInt("min_bq", 20),
        min_af: nonNegativeNumber("min_af", 0.05),
        min_coverage: positiveInt("min_coverage", 2),
        platform: platform,
        qual: nonNegativeNumber("qual", 12),
        show_ref: options.containsKey("show_ref") ? options.show_ref as Boolean : false,
        debug: options.containsKey("debug") ? options.debug as Boolean : false,
    ]
}

def _severusOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "min_sv_length",
        "min_support",
        "vaf_threshold",
        "single_bp",
        "resolve_overlaps",
        "between_junction_ins",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported Severus option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("Severus option '${name}' must be >= 1")
        }
        return number
    }
    def nonNegativeNumber = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        if (value == null || value.toString().trim() == "") {
            return null
        }
        def number = value as BigDecimal
        if (number < 0) {
            throw new IllegalArgumentException("Severus option '${name}' must be >= 0")
        }
        return number
    }
    return [
        threads: positiveInt("threads", 8),
        min_sv_length: positiveInt("min_sv_length", 50),
        min_support: positiveInt("min_support", 3),
        vaf_threshold: nonNegativeNumber("vaf_threshold", null),
        single_bp: options.containsKey("single_bp") ? options.single_bp as Boolean : true,
        resolve_overlaps: options.containsKey("resolve_overlaps") ? options.resolve_overlaps as Boolean : true,
        between_junction_ins: options.containsKey("between_junction_ins") ? options.between_junction_ins as Boolean : true,
    ]
}

def _somaticAnnotationOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "split_by_contig",
        "clinvar_filter_expression",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported somatic annotation option(s): ${unexpected.join(', ')}")
    }
    def threads = options.containsKey("threads") ? options.threads as Integer : 2
    if (threads < 1) {
        throw new IllegalArgumentException("somatic annotation option 'threads' must be >= 1")
    }
    def expression = (options.clinvar_filter_expression ?: "( exists CLNSIG )").toString()
    if (expression.contains("\n") || expression.contains("\r")) {
        throw new IllegalArgumentException("somatic annotation option 'clinvar_filter_expression' must be single-line")
    }
    return [
        threads: threads,
        split_by_contig: options.containsKey("split_by_contig") ? options.split_by_contig as Boolean : false,
        clinvar_filter_expression: expression,
    ]
}

def _familyGermlineSnpOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "candidate_contigs",
        "target_bed",
        "target_bed_digest",
        "ref_pct_full",
        "var_pct_full",
        "ref_var_max_ratio",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family germline SNP option(s): ${unexpected.join(', ')}")
    }
    def nonNegativeNumber = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as BigDecimal
        if (number < 0) {
            throw new IllegalArgumentException("family germline SNP option '${name}' must be >= 0")
        }
        return number
    }
    def contigs = options.candidate_contigs ?: []
    if (contigs instanceof String) {
        contigs = contigs.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(contigs instanceof Collection) || contigs.isEmpty()) {
        throw new IllegalArgumentException("family germline SNP option 'candidate_contigs' must be a non-empty list or comma-separated string")
    }
    return [
        candidate_contigs: contigs.collect { it.toString() },
        target_bed: (options.target_bed ?: "").toString(),
        target_bed_digest: (options.target_bed_digest ?: "").toString(),
        ref_pct_full: nonNegativeNumber("ref_pct_full", 0.03),
        var_pct_full: nonNegativeNumber("var_pct_full", 1.0),
        ref_var_max_ratio: nonNegativeNumber("ref_var_max_ratio", 1.2),
    ]
}

def _familyGermlineSnpDenovoOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "platform",
        "use_gpu",
        "gvcf",
        "show_ref",
        "phasing_info_in_bam",
        "keep_iupac_bases",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family germline SNP denovo option(s): ${unexpected.join(', ')}")
    }
    def nonNegativeInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 0) {
            throw new IllegalArgumentException("family germline SNP denovo option '${name}' must be >= 0")
        }
        return number
    }
    return [
        platform: (options.platform ?: "ont").toString(),
        use_gpu: nonNegativeInt("use_gpu", 0),
        gvcf: options.containsKey("gvcf") ? options.gvcf as Boolean : true,
        show_ref: options.containsKey("show_ref") ? options.show_ref as Boolean : true,
        phasing_info_in_bam: options.containsKey("phasing_info_in_bam") ? options.phasing_info_in_bam as Boolean : true,
        keep_iupac_bases: options.containsKey("keep_iupac_bases") ? options.keep_iupac_bases as Boolean : false,
    ]
}

def _familyGermlineSnpMergeOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "contigs",
        "platform",
        "print_ref_calls",
        "gvcf",
        "haploid_precise",
        "haploid_sensitive",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family germline SNP merge option(s): ${unexpected.join(', ')}")
    }
    def contigs = options.contigs ?: []
    if (contigs instanceof String) {
        contigs = contigs.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(contigs instanceof Collection) || contigs.isEmpty()) {
        throw new IllegalArgumentException("family germline SNP merge option 'contigs' must be a non-empty list or comma-separated string")
    }
    return [
        contigs: contigs.collect { it.toString() },
        platform: (options.platform ?: "ont").toString(),
        print_ref_calls: options.containsKey("print_ref_calls") ? options.print_ref_calls as Boolean : true,
        gvcf: options.containsKey("gvcf") ? options.gvcf as Boolean : true,
        haploid_precise: options.containsKey("haploid_precise") ? options.haploid_precise as Boolean : false,
        haploid_sensitive: options.containsKey("haploid_sensitive") ? options.haploid_sensitive as Boolean : false,
    ]
}

def _familyJointGenotypingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "sample_order",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family joint genotyping option(s): ${unexpected.join(', ')}")
    }
    def threads = options.containsKey("threads") ? options.threads as Integer : 4
    if (threads < 1) {
        throw new IllegalArgumentException("family joint genotyping option 'threads' must be >= 1")
    }
    def sample_order = options.sample_order ?: ["proband", "father", "mother"]
    if (sample_order instanceof String) {
        sample_order = sample_order.split(",").collect { it.trim() }.findAll { it }
    }
    if (sample_order.collect { it.toString() } != ["proband", "father", "mother"]) {
        throw new IllegalArgumentException("family joint genotyping option 'sample_order' must be proband,father,mother")
    }
    return [
        threads: threads,
        sample_order: sample_order.collect { it.toString() },
    ]
}

def _familyPedigreePhasingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "contigs",
        "enabled",
        "only_snvs",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family pedigree phasing option(s): ${unexpected.join(', ')}")
    }
    def contigs = options.contigs ?: []
    if (contigs instanceof String) {
        contigs = contigs.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(contigs instanceof Collection) || contigs.isEmpty()) {
        throw new IllegalArgumentException("family pedigree phasing option 'contigs' must be a non-empty list or comma-separated string")
    }
    return [
        contigs: contigs.collect { it.toString() },
        enabled: options.containsKey("enabled") ? options.enabled as Boolean : true,
        only_snvs: options.containsKey("only_snvs") ? options.only_snvs as Boolean : true,
    ]
}

def _familyHaplotaggingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "contigs",
        "enabled",
        "output_format",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family haplotagging option(s): ${unexpected.join(', ')}")
    }
    def contigs = options.contigs ?: []
    if (contigs instanceof String) {
        contigs = contigs.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(contigs instanceof Collection) || contigs.isEmpty()) {
        throw new IllegalArgumentException("family haplotagging option 'contigs' must be a non-empty list or comma-separated string")
    }
    return [
        contigs: contigs.collect { it.toString() },
        enabled: options.containsKey("enabled") ? options.enabled as Boolean : true,
        output_format: _choice("family_haplotagging_options.output_format", (options.output_format ?: "bam").toString(), ["bam", "cram"] as Set),
    ]
}

def _somaticPhasingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "contigs",
        "enabled",
        "only_snvs",
        "tool",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported somatic phasing option(s): ${unexpected.join(', ')}")
    }
    def contigs = options.contigs ?: []
    if (contigs instanceof String) {
        contigs = contigs.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(contigs instanceof Collection) || contigs.isEmpty()) {
        throw new IllegalArgumentException("somatic phasing option 'contigs' must be a non-empty list or comma-separated string")
    }
    return [
        contigs: contigs.collect { it.toString() },
        enabled: options.containsKey("enabled") ? options.enabled as Boolean : true,
        only_snvs: options.containsKey("only_snvs") ? options.only_snvs as Boolean : false,
        tool: _choice("somatic_phasing_options.tool", (options.tool ?: "whatshap").toString(), ["whatshap"] as Set),
    ]
}

def _somaticHaplotaggingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "contigs",
        "enabled",
        "output_format",
        "tool",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported somatic haplotagging option(s): ${unexpected.join(', ')}")
    }
    def contigs = options.contigs ?: []
    if (contigs instanceof String) {
        contigs = contigs.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(contigs instanceof Collection) || contigs.isEmpty()) {
        throw new IllegalArgumentException("somatic haplotagging option 'contigs' must be a non-empty list or comma-separated string")
    }
    return [
        contigs: contigs.collect { it.toString() },
        enabled: options.containsKey("enabled") ? options.enabled as Boolean : true,
        output_format: _choice("somatic_haplotagging_options.output_format", (options.output_format ?: "bam").toString(), ["bam", "cram"] as Set),
        tool: _choice("somatic_haplotagging_options.tool", (options.tool ?: "whatshap").toString(), ["whatshap"] as Set),
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

def _familySvMergingOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "roles",
        "allow_subset",
        "min_sv_length",
        "include_all_ctgs",
        "chromosome_codes",
        "genome_build",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family SV merging option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("family SV merging option '${name}' must be >= 1")
        }
        return number
    }
    def nonNegativeInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 0) {
            throw new IllegalArgumentException("family SV merging option '${name}' must be >= 0")
        }
        return number
    }
    def roles = options.roles ?: ["proband", "father", "mother"]
    if (roles instanceof String) {
        roles = roles.split(",").collect { it.trim() }.findAll { it }
    }
    def normalizedRoles = roles.collect { it.toString() }
    def allowedRoles = ["proband", "father", "mother"] as Set
    def invalidRoles = normalizedRoles.findAll { !allowedRoles.contains(it) }.sort()
    if (invalidRoles) {
        throw new IllegalArgumentException("family SV merging option 'roles' contains unsupported role(s): ${invalidRoles.join(', ')}")
    }
    if (normalizedRoles.isEmpty()) {
        throw new IllegalArgumentException("family SV merging option 'roles' must not be empty")
    }
    if (!options.containsKey("allow_subset") && normalizedRoles.size() != 3) {
        throw new IllegalArgumentException("family SV merging subset roles require family_sv_merging_options.allow_subset=true")
    }
    if (normalizedRoles.size() != 3 && !(options.allow_subset as Boolean)) {
        throw new IllegalArgumentException("family SV merging subset roles require family_sv_merging_options.allow_subset=true")
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
        throw new IllegalArgumentException("family SV merging option 'chromosome_codes' must be a non-empty list or comma-separated string")
    }
    return [
        threads: positiveInt("threads", 4),
        roles: normalizedRoles,
        allow_subset: options.containsKey("allow_subset") ? options.allow_subset as Boolean : false,
        min_sv_length: nonNegativeInt("min_sv_length", 30),
        include_all_ctgs: options.containsKey("include_all_ctgs") ? options.include_all_ctgs as Boolean : false,
        chromosome_codes: chromosomeCodes.collect { it.toString() },
        genome_build: (options.genome_build ?: "").toString(),
    ]
}

def _cnvOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "genome_build",
        "spectre_options",
        "qdnaseq_options",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported CNV option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("CNV option '${name}' must be >= 1")
        }
        return number
    }
    def spectreOptions = options.spectre_options instanceof Map ? options.spectre_options : [:]
    def spectreAllowed = ["min_cnv_len"] as Set
    def unexpectedSpectre = spectreOptions.keySet().collect { it.toString() }.findAll { !spectreAllowed.contains(it) }.sort()
    if (unexpectedSpectre) {
        throw new IllegalArgumentException("unsupported Spectre option(s): ${unexpectedSpectre.join(', ')}")
    }
    if (spectreOptions.containsKey("min_cnv_len") && (spectreOptions.min_cnv_len as Integer) < 0) {
        throw new IllegalArgumentException("Spectre option 'min_cnv_len' must be >= 0")
    }
    def qdnaseqOptions = options.qdnaseq_options instanceof Map ? options.qdnaseq_options : [:]
    def qdnaseqAllowed = ["bin_size"] as Set
    def unexpectedQdnaseq = qdnaseqOptions.keySet().collect { it.toString() }.findAll { !qdnaseqAllowed.contains(it) }.sort()
    if (unexpectedQdnaseq) {
        throw new IllegalArgumentException("unsupported QDNAseq option(s): ${unexpectedQdnaseq.join(', ')}")
    }
    return [
        threads: positiveInt("threads", 2),
        genome_build: (options.genome_build ?: "").toString(),
        spectre_options: spectreOptions,
        qdnaseq_options: [
            bin_size: qdnaseqOptions.containsKey("bin_size") ? positiveInt("qdnaseq_options.bin_size", qdnaseqOptions.bin_size) : 500,
        ],
    ]
}

def _strOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "min_support",
        "min_cluster_size",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported STR option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("STR option '${name}' must be >= 1")
        }
        return number
    }
    return [
        threads: positiveInt("threads", 2),
        min_support: positiveInt("min_support", 1),
        min_cluster_size: positiveInt("min_cluster_size", 1),
    ]
}

def _methylationOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "mod_codes",
        "combine_strands",
        "cpg",
        "preset",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported methylation option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("methylation option '${name}' must be >= 1")
        }
        return number
    }
    def preset = (options.preset ?: "").toString()
    if (preset && preset != "traditional") {
        throw new IllegalArgumentException("methylation option 'preset' must be one of: traditional")
    }
    def modCodes = options.mod_codes ?: ["m:5mC"]
    if (modCodes instanceof String) {
        modCodes = modCodes.split(",").collect { it.trim() }.findAll { it }
    }
    if (!(modCodes instanceof Collection) || modCodes.isEmpty()) {
        throw new IllegalArgumentException("methylation option 'mod_codes' must be a non-empty list or comma-separated string")
    }
    def hasDefaultBigWig = modCodes.collect { it.toString() }.any {
        def parts = it.split(":", 2)
        (parts.size() == 2 ? parts[1] : parts[0]) == "5mC"
    }
    if (!hasDefaultBigWig) {
        throw new IllegalArgumentException("methylation option 'mod_codes' must include m:5mC so the declared bigwig output can be produced")
    }
    return [
        threads: positiveInt("threads", 2),
        mod_codes: modCodes.collect { it.toString() },
        combine_strands: options.containsKey("combine_strands") ? options.combine_strands as Boolean : true,
        cpg: options.containsKey("cpg") ? options.cpg as Boolean : true,
        preset: preset,
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

def boundedSomaticGermlineHelperEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "germline_helper_vcf",
            "germline_helper_vcf_index",
            "germline_helper_manifest",
            "germline_helper_command_json",
            "germline_helper_logs",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_germline_helper.v1",
        entry_name: "somatic_germline_helper",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_germline_helper"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _requiredBoundedParam(params, "pair_id"),
        helper_sample_id: _requiredBoundedParam(params, "helper_sample_id"),
        helper_role: _choice("helper_role", _optionalBoundedParam(params, "helper_role", "normal"), ["tumour", "normal", "control"] as Set),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        helper_aggregate_xam: _requiredBoundedParam(params, "helper_aggregate_xam"),
        helper_aggregate_xam_index: _requiredBoundedParam(params, "helper_aggregate_xam_index"),
        helper_aggregate_xam_digest: _requiredBoundedParam(params, "helper_aggregate_xam_digest"),
        helper_aggregate_xam_index_digest: _requiredBoundedParam(params, "helper_aggregate_xam_index_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        clair3_model: _requiredBoundedParam(params, "clair3_model"),
        clair3_model_name: _optionalBoundedParam(params, "clair3_model_name", ""),
        clair3_model_digest: _requiredBoundedParam(params, "clair3_model_digest"),
        clair3_model_table_digest: _requiredBoundedParam(params, "clair3_model_table_digest"),
        germline_helper_config_digest: _requiredBoundedParam(params, "germline_helper_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        variant_options: _variantCallingOptions(params.variant_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticPhasingEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "selected_heterozygous_sites",
            "somatic_phased_vcf",
            "somatic_phased_vcf_index",
            "somatic_phasing_manifest",
            "somatic_phasing_command_json",
            "somatic_phasing_state",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_phasing.v1",
        entry_name: "somatic_phasing",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_phasing"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _optionalBoundedParam(params, "pair_id", ""),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        sample_role: _choice("sample_role", _requiredBoundedParam(params, "sample_role"), ["tumour", "normal", "control"] as Set),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _optionalBoundedParam(params, "relationship_snapshot_digest", ""),
        input_vcf: _requiredBoundedParam(params, "input_vcf"),
        input_vcf_index: _requiredBoundedParam(params, "input_vcf_index"),
        input_vcf_digest: _requiredBoundedParam(params, "input_vcf_digest"),
        input_vcf_index_digest: _requiredBoundedParam(params, "input_vcf_index_digest"),
        role_aggregate_xam: _requiredBoundedParam(params, "role_aggregate_xam"),
        role_aggregate_xam_index: _requiredBoundedParam(params, "role_aggregate_xam_index"),
        role_aggregate_xam_digest: _requiredBoundedParam(params, "role_aggregate_xam_digest"),
        role_aggregate_xam_index_digest: _requiredBoundedParam(params, "role_aggregate_xam_index_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        phasing_config_digest: _requiredBoundedParam(params, "phasing_config_digest"),
        phasing_options_digest: _requiredBoundedParam(params, "phasing_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        somatic_phasing_options: _somaticPhasingOptions(params.somatic_phasing_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticHaplotaggingEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_haplotagged_xam",
            "somatic_haplotagged_xam_index",
            "somatic_haplotagged_contig_manifest",
            "somatic_haplotagging_manifest",
            "somatic_haplotagging_command_json",
            "somatic_haplotagging_state",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_haplotagging.v1",
        entry_name: "somatic_haplotagging",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_haplotagging"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _optionalBoundedParam(params, "pair_id", ""),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        sample_role: _choice("sample_role", _requiredBoundedParam(params, "sample_role"), ["tumour", "normal", "control"] as Set),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _optionalBoundedParam(params, "relationship_snapshot_digest", ""),
        somatic_phased_vcf: _requiredBoundedParam(params, "somatic_phased_vcf"),
        somatic_phased_vcf_index: _requiredBoundedParam(params, "somatic_phased_vcf_index"),
        somatic_phased_vcf_digest: _requiredBoundedParam(params, "somatic_phased_vcf_digest"),
        somatic_phased_vcf_index_digest: _requiredBoundedParam(params, "somatic_phased_vcf_index_digest"),
        role_aggregate_xam: _requiredBoundedParam(params, "role_aggregate_xam"),
        role_aggregate_xam_index: _requiredBoundedParam(params, "role_aggregate_xam_index"),
        role_aggregate_xam_digest: _requiredBoundedParam(params, "role_aggregate_xam_digest"),
        role_aggregate_xam_index_digest: _requiredBoundedParam(params, "role_aggregate_xam_index_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        haplotagging_config_digest: _requiredBoundedParam(params, "haplotagging_config_digest"),
        haplotagging_options_digest: _requiredBoundedParam(params, "haplotagging_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        somatic_haplotagging_options: _somaticHaplotaggingOptions(params.somatic_haplotagging_options),
        output_paths: output_paths,
    ]
}

def boundedFamilyGermlineSnpEntryParams(params) {
    def expected_outputs = [
        "trio_candidate_manifest",
        "trio_candidate_beds",
        "trio_candidate_contigs",
        "trio_candidate_command_json",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    return [
        entry_schema: "wf-human-variation.bounded_family_germline_snp.v1",
        entry_name: "family_germline_snp",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_germline_snp"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        proband_sample_id: _requiredBoundedParam(params, "proband_sample_id"),
        proband_snp_vcf: _requiredBoundedParam(params, "proband_snp_vcf"),
        proband_snp_vcf_index: _requiredBoundedParam(params, "proband_snp_vcf_index"),
        proband_snp_vcf_digest: _requiredBoundedParam(params, "proband_snp_vcf_digest"),
        proband_snp_vcf_index_digest: _requiredBoundedParam(params, "proband_snp_vcf_index_digest"),
        father_sample_id: _requiredBoundedParam(params, "father_sample_id"),
        father_snp_vcf: _requiredBoundedParam(params, "father_snp_vcf"),
        father_snp_vcf_index: _requiredBoundedParam(params, "father_snp_vcf_index"),
        father_snp_vcf_digest: _requiredBoundedParam(params, "father_snp_vcf_digest"),
        father_snp_vcf_index_digest: _requiredBoundedParam(params, "father_snp_vcf_index_digest"),
        mother_sample_id: _requiredBoundedParam(params, "mother_sample_id"),
        mother_snp_vcf: _requiredBoundedParam(params, "mother_snp_vcf"),
        mother_snp_vcf_index: _requiredBoundedParam(params, "mother_snp_vcf_index"),
        mother_snp_vcf_digest: _requiredBoundedParam(params, "mother_snp_vcf_digest"),
        mother_snp_vcf_index_digest: _requiredBoundedParam(params, "mother_snp_vcf_index_digest"),
        clair3_nova_model: _requiredBoundedParam(params, "clair3_nova_model"),
        clair3_nova_model_digest: _requiredBoundedParam(params, "clair3_nova_model_digest"),
        family_germline_config_digest: _requiredBoundedParam(params, "family_germline_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_germline_options: _familyGermlineSnpOptions(params.family_germline_options),
        output_paths: output_paths,
    ]
}

def boundedFamilyGermlineSnpDenovoEntryParams(params) {
    def expected_outputs = [
        "trio_denovo_manifest",
        "trio_denovo_vcf_fragments",
        "trio_denovo_state",
        "trio_denovo_command_json",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    return [
        entry_schema: "wf-human-variation.bounded_family_germline_snp_denovo.v1",
        entry_name: "family_germline_snp_denovo",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_germline_snp"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        contig: _requiredBoundedParam(params, "contig"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        trio_candidate_beds: _requiredBoundedParam(params, "trio_candidate_beds"),
        trio_candidate_beds_digest: _requiredBoundedParam(params, "trio_candidate_beds_digest"),
        proband_sample_id: _requiredBoundedParam(params, "proband_sample_id"),
        proband_bam: _requiredBoundedParam(params, "proband_bam"),
        proband_bam_index: _requiredBoundedParam(params, "proband_bam_index"),
        proband_bam_digest: _requiredBoundedParam(params, "proband_bam_digest"),
        proband_bam_index_digest: _requiredBoundedParam(params, "proband_bam_index_digest"),
        father_sample_id: _requiredBoundedParam(params, "father_sample_id"),
        father_bam: _requiredBoundedParam(params, "father_bam"),
        father_bam_index: _requiredBoundedParam(params, "father_bam_index"),
        father_bam_digest: _requiredBoundedParam(params, "father_bam_digest"),
        father_bam_index_digest: _requiredBoundedParam(params, "father_bam_index_digest"),
        mother_sample_id: _requiredBoundedParam(params, "mother_sample_id"),
        mother_bam: _requiredBoundedParam(params, "mother_bam"),
        mother_bam_index: _requiredBoundedParam(params, "mother_bam_index"),
        mother_bam_digest: _requiredBoundedParam(params, "mother_bam_digest"),
        mother_bam_index_digest: _requiredBoundedParam(params, "mother_bam_index_digest"),
        clair3_nova_model: _requiredBoundedParam(params, "clair3_nova_model"),
        clair3_nova_model_digest: _requiredBoundedParam(params, "clair3_nova_model_digest"),
        family_germline_config_digest: _requiredBoundedParam(params, "family_germline_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_germline_denovo_options: _familyGermlineSnpDenovoOptions(params.family_germline_denovo_options),
        output_paths: output_paths,
    ]
}

def boundedFamilyGermlineSnpMergeEntryParams(params) {
    def expected_outputs = [
        "trio_snp_vcf",
        "trio_snp_vcf_index",
        "trio_snp_gvcf",
        "trio_snp_gvcf_index",
        "trio_merge_manifest",
        "trio_merge_command_json",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    return [
        entry_schema: "wf-human-variation.bounded_family_germline_snp_merge.v1",
        entry_name: "family_germline_snp_merge",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_germline_snp"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        role: _choice(
            "role",
            _requiredBoundedParam(params, "role"),
            ["proband", "father", "mother"] as Set
        ),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        trio_denovo_vcf_fragments: _requiredBoundedParam(params, "trio_denovo_vcf_fragments"),
        trio_denovo_vcf_fragments_digest: _requiredBoundedParam(params, "trio_denovo_vcf_fragments_digest"),
        trio_candidate_beds: _requiredBoundedParam(params, "trio_candidate_beds"),
        trio_candidate_beds_digest: _requiredBoundedParam(params, "trio_candidate_beds_digest"),
        snp_vcf: _requiredBoundedParam(params, "snp_vcf"),
        snp_vcf_index: _requiredBoundedParam(params, "snp_vcf_index"),
        snp_vcf_digest: _requiredBoundedParam(params, "snp_vcf_digest"),
        snp_vcf_index_digest: _requiredBoundedParam(params, "snp_vcf_index_digest"),
        snp_gvcf: _requiredBoundedParam(params, "snp_gvcf"),
        snp_gvcf_index: _requiredBoundedParam(params, "snp_gvcf_index"),
        snp_gvcf_digest: _requiredBoundedParam(params, "snp_gvcf_digest"),
        snp_gvcf_index_digest: _requiredBoundedParam(params, "snp_gvcf_index_digest"),
        clair3_nova_model_digest: _requiredBoundedParam(params, "clair3_nova_model_digest"),
        family_germline_config_digest: _requiredBoundedParam(params, "family_germline_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_germline_merge_options: _familyGermlineSnpMergeOptions(params.family_germline_merge_options),
        output_paths: output_paths,
    ]
}

def boundedFamilyJointGenotypingEntryParams(params) {
    def expected_outputs = [
        "family_joint_vcf",
        "family_joint_vcf_index",
        "family_joint_genotyping_manifest",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def proband_sample_id = _requiredBoundedParam(params, "proband_sample_id")
    def father_sample_id = _requiredBoundedParam(params, "father_sample_id")
    def mother_sample_id = _requiredBoundedParam(params, "mother_sample_id")
    _validateTrioRoleSamples(proband_sample_id, father_sample_id, mother_sample_id)
    return [
        entry_schema: "wf-human-variation.bounded_family_joint_genotyping.v1",
        entry_name: "family_joint_genotyping",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_joint_genotyping"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        pedigree_snapshot: _requiredBoundedParam(params, "pedigree_snapshot"),
        pedigree_snapshot_digest: _requiredBoundedParam(params, "pedigree_snapshot_digest"),
        proband_sample_id: proband_sample_id,
        proband_snp_gvcf: _requiredBoundedParam(params, "proband_snp_gvcf"),
        proband_snp_gvcf_index: _requiredBoundedParam(params, "proband_snp_gvcf_index"),
        proband_snp_gvcf_digest: _requiredBoundedParam(params, "proband_snp_gvcf_digest"),
        proband_snp_gvcf_index_digest: _requiredBoundedParam(params, "proband_snp_gvcf_index_digest"),
        father_sample_id: father_sample_id,
        father_snp_gvcf: _requiredBoundedParam(params, "father_snp_gvcf"),
        father_snp_gvcf_index: _requiredBoundedParam(params, "father_snp_gvcf_index"),
        father_snp_gvcf_digest: _requiredBoundedParam(params, "father_snp_gvcf_digest"),
        father_snp_gvcf_index_digest: _requiredBoundedParam(params, "father_snp_gvcf_index_digest"),
        mother_sample_id: mother_sample_id,
        mother_snp_gvcf: _requiredBoundedParam(params, "mother_snp_gvcf"),
        mother_snp_gvcf_index: _requiredBoundedParam(params, "mother_snp_gvcf_index"),
        mother_snp_gvcf_digest: _requiredBoundedParam(params, "mother_snp_gvcf_digest"),
        mother_snp_gvcf_index_digest: _requiredBoundedParam(params, "mother_snp_gvcf_index_digest"),
        glnexus_config: _requiredBoundedParam(params, "glnexus_config"),
        glnexus_config_digest: _requiredBoundedParam(params, "glnexus_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_joint_genotyping_options: _familyJointGenotypingOptions(params.family_joint_genotyping_options),
        output_paths: output_paths,
    ]
}

def boundedFamilyPedigreePhasingEntryParams(params) {
    def expected_outputs = [
        "pedigree_filtered_vcf",
        "pedigree_filtered_vcf_index",
        "per_sample_phased_vcf_fragments",
        "pedigree_phasing_manifest",
        "pedigree_phasing_state",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def proband_sample_id = _requiredBoundedParam(params, "proband_sample_id")
    def father_sample_id = _requiredBoundedParam(params, "father_sample_id")
    def mother_sample_id = _requiredBoundedParam(params, "mother_sample_id")
    _validateTrioRoleSamples(proband_sample_id, father_sample_id, mother_sample_id)
    return [
        entry_schema: "wf-human-variation.bounded_family_pedigree_phasing.v1",
        entry_name: "family_pedigree_phasing",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_pedigree_phasing"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        pedigree_snapshot: _requiredBoundedParam(params, "pedigree_snapshot"),
        pedigree_snapshot_digest: _requiredBoundedParam(params, "pedigree_snapshot_digest"),
        family_joint_vcf: _requiredBoundedParam(params, "family_joint_vcf"),
        family_joint_vcf_index: _requiredBoundedParam(params, "family_joint_vcf_index"),
        family_joint_vcf_digest: _requiredBoundedParam(params, "family_joint_vcf_digest"),
        family_joint_vcf_index_digest: _requiredBoundedParam(params, "family_joint_vcf_index_digest"),
        proband_sample_id: proband_sample_id,
        proband_bam: _requiredBoundedParam(params, "proband_bam"),
        proband_bam_index: _requiredBoundedParam(params, "proband_bam_index"),
        proband_bam_digest: _requiredBoundedParam(params, "proband_bam_digest"),
        proband_bam_index_digest: _requiredBoundedParam(params, "proband_bam_index_digest"),
        father_sample_id: father_sample_id,
        father_bam: _requiredBoundedParam(params, "father_bam"),
        father_bam_index: _requiredBoundedParam(params, "father_bam_index"),
        father_bam_digest: _requiredBoundedParam(params, "father_bam_digest"),
        father_bam_index_digest: _requiredBoundedParam(params, "father_bam_index_digest"),
        mother_sample_id: mother_sample_id,
        mother_bam: _requiredBoundedParam(params, "mother_bam"),
        mother_bam_index: _requiredBoundedParam(params, "mother_bam_index"),
        mother_bam_digest: _requiredBoundedParam(params, "mother_bam_digest"),
        mother_bam_index_digest: _requiredBoundedParam(params, "mother_bam_index_digest"),
        whatshap_config_digest: _requiredBoundedParam(params, "whatshap_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_pedigree_phasing_options: _familyPedigreePhasingOptions(params.family_pedigree_phasing_options),
        output_paths: output_paths,
    ]
}

def boundedFamilyHaplotaggingEntryParams(params) {
    def expected_outputs = [
        "family_haplotagged_alignments",
        "family_haplotagged_contig_manifest",
        "family_haplotagging_manifest",
        "family_haplotagging_state",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def proband_sample_id = _requiredBoundedParam(params, "proband_sample_id")
    def father_sample_id = _requiredBoundedParam(params, "father_sample_id")
    def mother_sample_id = _requiredBoundedParam(params, "mother_sample_id")
    _validateTrioRoleSamples(proband_sample_id, father_sample_id, mother_sample_id)
    return [
        entry_schema: "wf-human-variation.bounded_family_haplotagging.v1",
        entry_name: "family_haplotagging",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_haplotagging"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        pedigree_filtered_vcf: _requiredBoundedParam(params, "pedigree_filtered_vcf"),
        pedigree_filtered_vcf_index: _requiredBoundedParam(params, "pedigree_filtered_vcf_index"),
        pedigree_filtered_vcf_digest: _requiredBoundedParam(params, "pedigree_filtered_vcf_digest"),
        pedigree_filtered_vcf_index_digest: _requiredBoundedParam(params, "pedigree_filtered_vcf_index_digest"),
        proband_sample_id: proband_sample_id,
        proband_xam: _requiredBoundedParam(params, "proband_xam"),
        proband_xam_index: _requiredBoundedParam(params, "proband_xam_index"),
        proband_xam_digest: _requiredBoundedParam(params, "proband_xam_digest"),
        proband_xam_index_digest: _requiredBoundedParam(params, "proband_xam_index_digest"),
        father_sample_id: father_sample_id,
        father_xam: _requiredBoundedParam(params, "father_xam"),
        father_xam_index: _requiredBoundedParam(params, "father_xam_index"),
        father_xam_digest: _requiredBoundedParam(params, "father_xam_digest"),
        father_xam_index_digest: _requiredBoundedParam(params, "father_xam_index_digest"),
        mother_sample_id: mother_sample_id,
        mother_xam: _requiredBoundedParam(params, "mother_xam"),
        mother_xam_index: _requiredBoundedParam(params, "mother_xam_index"),
        mother_xam_digest: _requiredBoundedParam(params, "mother_xam_digest"),
        mother_xam_index_digest: _requiredBoundedParam(params, "mother_xam_index_digest"),
        whatshap_config_digest: _requiredBoundedParam(params, "whatshap_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_haplotagging_options: _familyHaplotaggingOptions(params.family_haplotagging_options),
        output_paths: output_paths,
    ]
}

def boundedFamilySvCallingEntryParams(params) {
    def expected_outputs = [
        "structural_variant_vcf",
        "structural_variant_vcf_index",
        "structural_variant_snf",
        "family_sv_calling_command_json",
        "family_sv_calling_manifest",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def role = _choice(
        "role",
        _requiredBoundedParam(params, "role"),
        ["proband", "father", "mother"] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_family_sv_calling.v1",
        entry_name: "family_sv_calling",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_sv_calling"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        role: role,
        sample_id: _requiredBoundedParam(params, "sample_id"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        aggregate_xam: _requiredBoundedParam(params, "aggregate_xam"),
        aggregate_xam_index: _requiredBoundedParam(params, "aggregate_xam_index"),
        aggregate_xam_digest: _requiredBoundedParam(params, "aggregate_xam_digest"),
        aggregate_xam_index_digest: _requiredBoundedParam(params, "aggregate_xam_index_digest"),
        mosdepth_summary: _requiredBoundedParam(params, "mosdepth_summary"),
        mosdepth_summary_digest: _requiredBoundedParam(params, "mosdepth_summary_digest"),
        target_bed: _requiredBoundedParam(params, "target_bed"),
        target_bed_digest: _requiredBoundedParam(params, "target_bed_digest"),
        sniffles_config_digest: _requiredBoundedParam(params, "sniffles_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        structural_variant_options: _structuralVariantOptions(params.structural_variant_options),
        output_paths: output_paths,
    ]
}

def _familyMendelianAssessmentOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "variant_classes",
        "allow_subset",
        "mendelian_mode",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported family Mendelian assessment option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("family Mendelian assessment option '${name}' must be >= 1")
        }
        return number
    }
    def variantClasses = options.variant_classes ?: ["snp", "sv"]
    if (variantClasses instanceof String) {
        variantClasses = variantClasses.split(",").collect { it.trim() }.findAll { it }
    }
    def normalizedClasses = variantClasses.collect { it.toString() }
    def allowedClasses = ["snp", "sv"] as Set
    def invalidClasses = normalizedClasses.findAll { !allowedClasses.contains(it) }.sort()
    if (invalidClasses) {
        throw new IllegalArgumentException("family Mendelian assessment option 'variant_classes' contains unsupported class(es): ${invalidClasses.join(', ')}")
    }
    if (normalizedClasses.isEmpty()) {
        throw new IllegalArgumentException("family Mendelian assessment option 'variant_classes' must not be empty")
    }
    if (normalizedClasses.size() != normalizedClasses.toSet().size()) {
        throw new IllegalArgumentException("family Mendelian assessment option 'variant_classes' must not contain duplicates")
    }
    if (normalizedClasses.size() != 2 && !(options.allow_subset as Boolean)) {
        throw new IllegalArgumentException("family Mendelian assessment subset classes require family_mendelian_assessment_options.allow_subset=true")
    }
    return [
        threads: positiveInt("threads", 2),
        variant_classes: normalizedClasses,
        allow_subset: options.containsKey("allow_subset") ? options.allow_subset as Boolean : false,
        mendelian_mode: _choice(
            "family_mendelian_assessment_options.mendelian_mode",
            (options.mendelian_mode ?: "rtg").toString(),
            ["rtg"] as Set
        ),
    ]
}

def boundedFamilySvMergingEntryParams(params) {
    def options = _familySvMergingOptions(params.family_sv_merging_options)
    def expected_outputs = [
        "family_sv_vcf",
        "family_sv_vcf_index",
        "family_sv_merging_command_json",
        "family_sv_merging_manifest",
        "family_sv_merging_state",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def entry = [
        entry_schema: "wf-human-variation.bounded_family_sv_merging.v1",
        entry_name: "family_sv_merging",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_sv_merging"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        target_bed: _requiredBoundedParam(params, "target_bed"),
        target_bed_digest: _requiredBoundedParam(params, "target_bed_digest"),
        sniffles_config_digest: _requiredBoundedParam(params, "sniffles_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_sv_merging_options: options,
        output_paths: output_paths,
    ]
    def roleParams = [
        proband: [
            sample_id: "proband_sample_id",
            snf: "proband_snf",
            snf_digest: "proband_snf_digest",
            snf_reference_digest: "proband_snf_reference_digest",
            snf_genome_build: "proband_snf_genome_build",
        ],
        father: [
            sample_id: "father_sample_id",
            snf: "father_snf",
            snf_digest: "father_snf_digest",
            snf_reference_digest: "father_snf_reference_digest",
            snf_genome_build: "father_snf_genome_build",
        ],
        mother: [
            sample_id: "mother_sample_id",
            snf: "mother_snf",
            snf_digest: "mother_snf_digest",
            snf_reference_digest: "mother_snf_reference_digest",
            snf_genome_build: "mother_snf_genome_build",
        ],
    ]
    for (role in ["proband", "father", "mother"]) {
        def names = roleParams[role]
        if (options.roles.contains(role)) {
            entry[names.sample_id] = _requiredBoundedParam(params, names.sample_id)
            entry[names.snf] = _requiredBoundedParam(params, names.snf)
            entry[names.snf_digest] = _requiredBoundedParam(params, names.snf_digest)
            entry[names.snf_reference_digest] = _requiredBoundedParam(params, names.snf_reference_digest)
            entry[names.snf_genome_build] = _optionalBoundedParam(params, names.snf_genome_build, "")
        }
        else {
            entry[names.sample_id] = _optionalBoundedParam(params, names.sample_id, "")
            entry[names.snf] = _optionalBoundedParam(params, names.snf, "")
            entry[names.snf_digest] = _optionalBoundedParam(params, names.snf_digest, "")
            entry[names.snf_reference_digest] = _optionalBoundedParam(params, names.snf_reference_digest, "")
            entry[names.snf_genome_build] = _optionalBoundedParam(params, names.snf_genome_build, "")
        }
    }
    return entry
}

def boundedFamilyMendelianAssessmentEntryParams(params) {
    def options = _familyMendelianAssessmentOptions(params.family_mendelian_assessment_options)
    def expected_outputs = [
        "family_rtg_snp_summary",
        "family_rtg_sv_summary",
        "mendelian_summary",
        "mendelian_metrics",
        "family_mendelian_assessment_manifest",
        "family_mendelian_assessment_state",
        "family_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def entry = [
        entry_schema: "wf-human-variation.bounded_family_mendelian_assessment.v1",
        entry_name: "family_mendelian_assessment",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["family_mendelian_assessment"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        family_id: _requiredBoundedParam(params, "family_id"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        reference_sdf: _requiredBoundedParam(params, "reference_sdf"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        pedigree_snapshot: _requiredBoundedParam(params, "pedigree_snapshot"),
        pedigree_snapshot_digest: _requiredBoundedParam(params, "pedigree_snapshot_digest"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        rtg_config_digest: _requiredBoundedParam(params, "rtg_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        family_mendelian_assessment_options: options,
        output_paths: output_paths,
    ]
    if (options.variant_classes.contains("snp")) {
        entry.family_joint_vcf = _requiredBoundedParam(params, "family_joint_vcf")
        entry.family_joint_vcf_index = _requiredBoundedParam(params, "family_joint_vcf_index")
        entry.family_joint_vcf_digest = _requiredBoundedParam(params, "family_joint_vcf_digest")
        entry.family_joint_vcf_index_digest = _requiredBoundedParam(params, "family_joint_vcf_index_digest")
    }
    else {
        entry.family_joint_vcf = _optionalBoundedParam(params, "family_joint_vcf", "")
        entry.family_joint_vcf_index = _optionalBoundedParam(params, "family_joint_vcf_index", "")
        entry.family_joint_vcf_digest = _optionalBoundedParam(params, "family_joint_vcf_digest", "")
        entry.family_joint_vcf_index_digest = _optionalBoundedParam(params, "family_joint_vcf_index_digest", "")
    }
    if (options.variant_classes.contains("sv")) {
        entry.family_sv_vcf = _requiredBoundedParam(params, "family_sv_vcf")
        entry.family_sv_vcf_index = _requiredBoundedParam(params, "family_sv_vcf_index")
        entry.family_sv_vcf_digest = _requiredBoundedParam(params, "family_sv_vcf_digest")
        entry.family_sv_vcf_index_digest = _requiredBoundedParam(params, "family_sv_vcf_index_digest")
    }
    else {
        entry.family_sv_vcf = _optionalBoundedParam(params, "family_sv_vcf", "")
        entry.family_sv_vcf_index = _optionalBoundedParam(params, "family_sv_vcf_index", "")
        entry.family_sv_vcf_digest = _optionalBoundedParam(params, "family_sv_vcf_digest", "")
        entry.family_sv_vcf_index_digest = _optionalBoundedParam(params, "family_sv_vcf_index_digest", "")
    }
    return entry
}

def boundedSomaticTumourOnlySnvEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_snv_vcf",
            "somatic_snv_vcf_index",
            "somatic_tumour_only_snv_manifest",
            "somatic_tumour_only_snv_command_json",
            "somatic_tumour_only_snv_logs",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_tumour_only_snv.v1",
        entry_name: "somatic_tumour_only_snv",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_tumour_only_snv"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        role: _choice("role", _optionalBoundedParam(params, "role", "tumour"), ["tumour"] as Set),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        aggregate_xam: _requiredBoundedParam(params, "aggregate_xam"),
        aggregate_xam_index: _requiredBoundedParam(params, "aggregate_xam_index"),
        aggregate_xam_digest: _requiredBoundedParam(params, "aggregate_xam_digest"),
        aggregate_xam_index_digest: _requiredBoundedParam(params, "aggregate_xam_index_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        clairs_to_model: _requiredBoundedParam(params, "clairs_to_model"),
        clairs_to_model_name: _optionalBoundedParam(params, "clairs_to_model_name", ""),
        clairs_to_model_digest: _requiredBoundedParam(params, "clairs_to_model_digest"),
        clairs_to_model_table_digest: _requiredBoundedParam(params, "clairs_to_model_table_digest"),
        clairs_to_database_bundle: _requiredBoundedParam(params, "clairs_to_database_bundle"),
        clairs_to_database_bundle_digest: _requiredBoundedParam(params, "clairs_to_database_bundle_digest"),
        clairs_to_config_digest: _requiredBoundedParam(params, "clairs_to_config_digest"),
        clairs_to_options_digest: _requiredBoundedParam(params, "clairs_to_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        target_bed: _optionalBoundedParam(params, "target_bed", ""),
        target_bed_digest: _optionalBoundedParam(params, "target_bed_digest", ""),
        candidate_vcf: _optionalBoundedParam(params, "candidate_vcf", ""),
        candidate_vcf_index: _optionalBoundedParam(params, "candidate_vcf_index", ""),
        candidate_vcf_digest: _optionalBoundedParam(params, "candidate_vcf_digest", ""),
        genotyping_vcf: _optionalBoundedParam(params, "genotyping_vcf", ""),
        genotyping_vcf_index: _optionalBoundedParam(params, "genotyping_vcf_index", ""),
        genotyping_vcf_digest: _optionalBoundedParam(params, "genotyping_vcf_digest", ""),
        clairs_to_options: _clairsToOptions(params.clairs_to_options),
        output_paths: output_paths,
    ]
}

def _clairsOptions(def raw) {
    def options = raw instanceof Map ? raw : [:]
    def allowed = [
        "threads",
        "chunk_num",
        "chunk_size",
        "ctg_name",
        "enable_phasing",
        "include_all_ctgs",
        "indel_min_af",
        "min_bq",
        "min_af",
        "min_coverage",
        "platform",
        "qual",
        "show_germline",
        "show_ref",
    ] as Set
    def unexpected = options.keySet().collect { it.toString() }.findAll { !allowed.contains(it) }.sort()
    if (unexpected) {
        throw new IllegalArgumentException("unsupported ClairS option(s): ${unexpected.join(', ')}")
    }
    def positiveInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 1) {
            throw new IllegalArgumentException("ClairS option '${name}' must be >= 1")
        }
        return number
    }
    def nonNegativeInt = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as Integer
        if (number < 0) {
            throw new IllegalArgumentException("ClairS option '${name}' must be >= 0")
        }
        return number
    }
    def nonNegativeNumber = { name, defaultValue ->
        def value = options.containsKey(name) ? options[name] : defaultValue
        def number = value as BigDecimal
        if (number < 0) {
            throw new IllegalArgumentException("ClairS option '${name}' must be >= 0")
        }
        return number
    }
    def platform = (options.platform ?: "ont").toString()
    if (platform != "ont") {
        throw new IllegalArgumentException("ClairS option 'platform' must be ont")
    }
    return [
        threads: positiveInt("threads", 4),
        chunk_num: nonNegativeInt("chunk_num", 0),
        chunk_size: positiveInt("chunk_size", 5000000),
        ctg_name: (options.ctg_name ?: "").toString(),
        enable_phasing: options.containsKey("enable_phasing") ? options.enable_phasing as Boolean : false,
        include_all_ctgs: options.containsKey("include_all_ctgs") ? options.include_all_ctgs as Boolean : false,
        indel_min_af: nonNegativeNumber("indel_min_af", 0.15),
        min_bq: nonNegativeInt("min_bq", 20),
        min_af: nonNegativeNumber("min_af", 0.05),
        min_coverage: positiveInt("min_coverage", 2),
        platform: platform,
        qual: nonNegativeNumber("qual", 2),
        show_germline: options.containsKey("show_germline") ? options.show_germline as Boolean : false,
        show_ref: options.containsKey("show_ref") ? options.show_ref as Boolean : false,
    ]
}

def boundedSomaticPairedSnvCandidateEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_candidate_snv",
            "somatic_candidate_indel",
            "somatic_candidate_hybrid",
            "somatic_candidate_bed",
            "somatic_paired_snv_candidate_manifest",
            "somatic_paired_snv_candidate_command_json",
            "somatic_paired_snv_candidate_logs",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_paired_snv_candidate.v1",
        entry_name: "somatic_paired_snv_candidate",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_paired_snv"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _requiredBoundedParam(params, "pair_id"),
        region_id: _optionalBoundedParam(params, "region_id", "all"),
        contig: _requiredBoundedParam(params, "contig"),
        chunk_id: _optionalBoundedParam(params, "chunk_id", "1"),
        total_chunks: _optionalBoundedParam(params, "total_chunks", "1"),
        tumour_sample_id: _requiredBoundedParam(params, "tumour_sample_id"),
        normal_or_control_sample_id: _requiredBoundedParam(params, "normal_or_control_sample_id"),
        paired_role: _choice("paired_role", _optionalBoundedParam(params, "paired_role", "normal"), ["normal", "control"] as Set),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        tumour_aggregate_xam: _requiredBoundedParam(params, "tumour_aggregate_xam"),
        tumour_aggregate_xam_index: _requiredBoundedParam(params, "tumour_aggregate_xam_index"),
        tumour_aggregate_xam_digest: _requiredBoundedParam(params, "tumour_aggregate_xam_digest"),
        tumour_aggregate_xam_index_digest: _requiredBoundedParam(params, "tumour_aggregate_xam_index_digest"),
        normal_or_control_aggregate_xam: _requiredBoundedParam(params, "normal_or_control_aggregate_xam"),
        normal_or_control_aggregate_xam_index: _requiredBoundedParam(params, "normal_or_control_aggregate_xam_index"),
        normal_or_control_aggregate_xam_digest: _requiredBoundedParam(params, "normal_or_control_aggregate_xam_digest"),
        normal_or_control_aggregate_xam_index_digest: _requiredBoundedParam(params, "normal_or_control_aggregate_xam_index_digest"),
        normal_vcf: _requiredBoundedParam(params, "normal_vcf"),
        normal_vcf_index: _requiredBoundedParam(params, "normal_vcf_index"),
        normal_vcf_digest: _requiredBoundedParam(params, "normal_vcf_digest"),
        normal_vcf_index_digest: _requiredBoundedParam(params, "normal_vcf_index_digest"),
        shared_region_bed: _requiredBoundedParam(params, "shared_region_bed"),
        shared_region_bed_digest: _requiredBoundedParam(params, "shared_region_bed_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        clairs_model: _requiredBoundedParam(params, "clairs_model"),
        clairs_model_name: _optionalBoundedParam(params, "clairs_model_name", ""),
        clairs_model_digest: _requiredBoundedParam(params, "clairs_model_digest"),
        clairs_model_table_digest: _requiredBoundedParam(params, "clairs_model_table_digest"),
        clairs_reference_bundle: _requiredBoundedParam(params, "clairs_reference_bundle"),
        clairs_reference_bundle_digest: _requiredBoundedParam(params, "clairs_reference_bundle_digest"),
        clairs_config_digest: _requiredBoundedParam(params, "clairs_config_digest"),
        clairs_options_digest: _requiredBoundedParam(params, "clairs_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        target_bed: _optionalBoundedParam(params, "target_bed", ""),
        target_bed_digest: _optionalBoundedParam(params, "target_bed_digest", ""),
        genotyping_vcf: _optionalBoundedParam(params, "genotyping_vcf", ""),
        genotyping_vcf_index: _optionalBoundedParam(params, "genotyping_vcf_index", ""),
        genotyping_vcf_digest: _optionalBoundedParam(params, "genotyping_vcf_digest", ""),
        clairs_options: _clairsOptions(params.clairs_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticPairedSnvPileupEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_pileup_prediction_fragments",
            "somatic_pileup_prediction_manifest",
            "somatic_pileup_prediction_command_json",
            "somatic_paired_snv_pileup_logs",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_paired_snv_pileup.v1",
        entry_name: "somatic_paired_snv_pileup",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_paired_snv"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _requiredBoundedParam(params, "pair_id"),
        region_id: _requiredBoundedParam(params, "region_id"),
        contig: _requiredBoundedParam(params, "contig"),
        variant_type: _choice("variant_type", _optionalBoundedParam(params, "variant_type", "snv"), ["snv", "indel"] as Set),
        tumour_sample_id: _requiredBoundedParam(params, "tumour_sample_id"),
        normal_or_control_sample_id: _requiredBoundedParam(params, "normal_or_control_sample_id"),
        paired_role: _choice("paired_role", _optionalBoundedParam(params, "paired_role", "normal"), ["normal", "control"] as Set),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        tumour_aggregate_xam: _requiredBoundedParam(params, "tumour_aggregate_xam"),
        tumour_aggregate_xam_index: _requiredBoundedParam(params, "tumour_aggregate_xam_index"),
        tumour_aggregate_xam_digest: _requiredBoundedParam(params, "tumour_aggregate_xam_digest"),
        tumour_aggregate_xam_index_digest: _requiredBoundedParam(params, "tumour_aggregate_xam_index_digest"),
        normal_or_control_aggregate_xam: _requiredBoundedParam(params, "normal_or_control_aggregate_xam"),
        normal_or_control_aggregate_xam_index: _requiredBoundedParam(params, "normal_or_control_aggregate_xam_index"),
        normal_or_control_aggregate_xam_digest: _requiredBoundedParam(params, "normal_or_control_aggregate_xam_digest"),
        normal_or_control_aggregate_xam_index_digest: _requiredBoundedParam(params, "normal_or_control_aggregate_xam_index_digest"),
        candidate_bed: _requiredBoundedParam(params, "candidate_bed"),
        candidate_bed_digest: _requiredBoundedParam(params, "candidate_bed_digest"),
        candidate_variants: _requiredBoundedParam(params, "candidate_variants"),
        candidate_variants_digest: _requiredBoundedParam(params, "candidate_variants_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        clairs_model: _requiredBoundedParam(params, "clairs_model"),
        clairs_model_name: _optionalBoundedParam(params, "clairs_model_name", ""),
        clairs_model_digest: _requiredBoundedParam(params, "clairs_model_digest"),
        clairs_model_table_digest: _requiredBoundedParam(params, "clairs_model_table_digest"),
        clairs_config_digest: _requiredBoundedParam(params, "clairs_config_digest"),
        clairs_options_digest: _requiredBoundedParam(params, "clairs_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        clairs_options: _clairsOptions(params.clairs_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticPairedSnvFullAlignmentEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_full_alignment_prediction_fragments",
            "somatic_full_alignment_prediction_manifest",
            "somatic_full_alignment_prediction_command_json",
            "somatic_paired_snv_full_alignment_logs",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_paired_snv_full_alignment.v1",
        entry_name: "somatic_paired_snv_full_alignment",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_paired_snv"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _requiredBoundedParam(params, "pair_id"),
        region_id: _requiredBoundedParam(params, "region_id"),
        contig: _requiredBoundedParam(params, "contig"),
        variant_type: _choice("variant_type", _optionalBoundedParam(params, "variant_type", "snv"), ["snv", "indel"] as Set),
        alignment_state: _choice("alignment_state", _optionalBoundedParam(params, "alignment_state", "unphased"), ["unphased", "phased"] as Set),
        tumour_sample_id: _requiredBoundedParam(params, "tumour_sample_id"),
        normal_or_control_sample_id: _requiredBoundedParam(params, "normal_or_control_sample_id"),
        paired_role: _choice("paired_role", _optionalBoundedParam(params, "paired_role", "normal"), ["normal", "control"] as Set),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        tumour_alignment_xam: _requiredBoundedParam(params, "tumour_alignment_xam"),
        tumour_alignment_xam_index: _requiredBoundedParam(params, "tumour_alignment_xam_index"),
        tumour_alignment_xam_digest: _requiredBoundedParam(params, "tumour_alignment_xam_digest"),
        tumour_alignment_xam_index_digest: _requiredBoundedParam(params, "tumour_alignment_xam_index_digest"),
        normal_or_control_alignment_xam: _requiredBoundedParam(params, "normal_or_control_alignment_xam"),
        normal_or_control_alignment_xam_index: _requiredBoundedParam(params, "normal_or_control_alignment_xam_index"),
        normal_or_control_alignment_xam_digest: _requiredBoundedParam(params, "normal_or_control_alignment_xam_digest"),
        normal_or_control_alignment_xam_index_digest: _requiredBoundedParam(params, "normal_or_control_alignment_xam_index_digest"),
        candidate_bed: _requiredBoundedParam(params, "candidate_bed"),
        candidate_bed_digest: _requiredBoundedParam(params, "candidate_bed_digest"),
        candidate_variants: _requiredBoundedParam(params, "candidate_variants"),
        candidate_variants_digest: _requiredBoundedParam(params, "candidate_variants_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        clairs_model: _requiredBoundedParam(params, "clairs_model"),
        clairs_model_name: _optionalBoundedParam(params, "clairs_model_name", ""),
        clairs_model_digest: _requiredBoundedParam(params, "clairs_model_digest"),
        clairs_model_table_digest: _requiredBoundedParam(params, "clairs_model_table_digest"),
        clairs_config_digest: _requiredBoundedParam(params, "clairs_config_digest"),
        clairs_options_digest: _requiredBoundedParam(params, "clairs_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        clairs_options: _clairsOptions(params.clairs_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticPairedSnvMergeEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_snv_vcf",
            "somatic_snv_vcf_index",
            "somatic_paired_snv_manifest",
            "somatic_paired_snv_command_json",
            "somatic_paired_snv_logs",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_paired_snv_merge.v1",
        entry_name: "somatic_paired_snv_merge",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_paired_snv"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _requiredBoundedParam(params, "pair_id"),
        variant_type: _choice("variant_type", _optionalBoundedParam(params, "variant_type", "snv"), ["snv", "indel"] as Set),
        tumour_sample_id: _requiredBoundedParam(params, "tumour_sample_id"),
        normal_or_control_sample_id: _requiredBoundedParam(params, "normal_or_control_sample_id"),
        paired_role: _choice("paired_role", _optionalBoundedParam(params, "paired_role", "normal"), ["normal", "control"] as Set),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _requiredBoundedParam(params, "relationship_snapshot_digest"),
        pileup_prediction_fragments: _requiredBoundedParam(params, "pileup_prediction_fragments"),
        pileup_prediction_fragments_digest: _requiredBoundedParam(params, "pileup_prediction_fragments_digest"),
        full_alignment_prediction_fragments: _requiredBoundedParam(params, "full_alignment_prediction_fragments"),
        full_alignment_prediction_fragments_digest: _requiredBoundedParam(params, "full_alignment_prediction_fragments_digest"),
        contigs_file: _requiredBoundedParam(params, "contigs_file"),
        contigs_file_digest: _requiredBoundedParam(params, "contigs_file_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        clairs_config_digest: _requiredBoundedParam(params, "clairs_config_digest"),
        clairs_options_digest: _requiredBoundedParam(params, "clairs_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        clairs_options: _clairsOptions(params.clairs_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticQcEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_shared_regions_bed",
            "somatic_rejected_regions_summary",
            "somatic_qc_manifest",
            "somatic_qc_metrics",
            "somatic_provenance",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_qc.v1",
        entry_name: "somatic_qc",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_qc"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        pair_id: _optionalBoundedParam(params, "pair_id", ""),
        tumour_sample_id: _requiredBoundedParam(params, "tumour_sample_id"),
        normal_or_control_sample_id: _requiredBoundedParam(params, "normal_or_control_sample_id"),
        normal_or_control_role: _choice(
            "normal_or_control_role",
            _optionalBoundedParam(params, "normal_or_control_role", "normal"),
            ["normal", "control"] as Set
        ),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        reference_genome_build: _optionalBoundedParam(params, "reference_genome_build", ""),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        relationship_snapshot_digest: _optionalBoundedParam(params, "relationship_snapshot_digest", ""),
        tumour_mosdepth_regions: _requiredBoundedParam(params, "tumour_mosdepth_regions"),
        tumour_mosdepth_regions_digest: _requiredBoundedParam(params, "tumour_mosdepth_regions_digest"),
        normal_or_control_mosdepth_regions: _requiredBoundedParam(params, "normal_or_control_mosdepth_regions"),
        normal_or_control_mosdepth_regions_digest: _requiredBoundedParam(params, "normal_or_control_mosdepth_regions_digest"),
        target_bed: _optionalBoundedParam(params, "target_bed", ""),
        target_bed_digest: _optionalBoundedParam(params, "target_bed_digest", ""),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        coverage_thresholds_digest: _requiredBoundedParam(params, "coverage_thresholds_digest"),
        somatic_qc_config_digest: _requiredBoundedParam(params, "somatic_qc_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        output_paths: output_paths,
    ]
}

def boundedSomaticTumourOnlySvEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_sv_vcf",
            "somatic_sv_vcf_index",
            "somatic_sv_raw_directory",
            "somatic_tumour_only_sv_manifest",
            "somatic_tumour_only_sv_command_json",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    def aggregate_xam_kind = _choice(
        "aggregate_xam_kind",
        _optionalBoundedParam(params, "aggregate_xam_kind", "bam"),
        ["bam", "cram"] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_tumour_only_sv.v1",
        entry_name: "somatic_tumour_only_sv",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_tumour_only_sv"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        role: _choice("role", _optionalBoundedParam(params, "role", "tumour"), ["tumour"] as Set),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        aggregate_xam: _requiredBoundedParam(params, "aggregate_xam"),
        aggregate_xam_index: _requiredBoundedParam(params, "aggregate_xam_index"),
        aggregate_xam_kind: aggregate_xam_kind,
        aggregate_xam_digest: _requiredBoundedParam(params, "aggregate_xam_digest"),
        aggregate_xam_index_digest: _requiredBoundedParam(params, "aggregate_xam_index_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        reference_digest: _requiredBoundedParam(params, "reference_digest"),
        reference_genome_build: _optionalBoundedParam(params, "reference_genome_build", ""),
        pon_file: _optionalBoundedParam(params, "pon_file", ""),
        pon_file_digest: _optionalBoundedParam(params, "pon_file_digest", ""),
        trf_bed: _optionalBoundedParam(params, "trf_bed", ""),
        trf_bed_digest: _optionalBoundedParam(params, "trf_bed_digest", ""),
        severus_config_digest: _requiredBoundedParam(params, "severus_config_digest"),
        severus_options_digest: _requiredBoundedParam(params, "severus_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        severus_options: _severusOptions(params.severus_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticAnnotationEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_annotated_vcf",
            "somatic_annotated_vcf_index",
            "somatic_clinvar_vcf",
            "somatic_clinvar_vcf_index",
            "somatic_annotation_manifest",
            "somatic_annotation_command_json",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    def mode = _choice(
        "annotation_mode",
        _requiredBoundedParam(params, "annotation_mode"),
        ["snv", "sv"] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_annotation.v1",
        entry_name: "somatic_annotation",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_annotation"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        source_output_artefact_id: _requiredBoundedParam(params, "source_output_artefact_id"),
        annotation_mode: mode,
        sample_id: _optionalBoundedParam(params, "sample_id", ""),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        reference_genome_build: _requiredBoundedParam(params, "reference_genome_build"),
        source_vcf: _requiredBoundedParam(params, "source_vcf"),
        source_vcf_index: _requiredBoundedParam(params, "source_vcf_index"),
        source_vcf_digest: _requiredBoundedParam(params, "source_vcf_digest"),
        source_vcf_index_digest: _requiredBoundedParam(params, "source_vcf_index_digest"),
        snpeff_database: _requiredBoundedParam(params, "snpeff_database"),
        snpeff_database_name: _requiredBoundedParam(params, "snpeff_database_name"),
        snpeff_database_digest: _requiredBoundedParam(params, "snpeff_database_digest"),
        clinvar_vcf: _optionalBoundedParam(params, "clinvar_vcf", ""),
        clinvar_vcf_index: _optionalBoundedParam(params, "clinvar_vcf_index", ""),
        clinvar_vcf_digest: _optionalBoundedParam(params, "clinvar_vcf_digest", ""),
        sift_annotation: _optionalBoundedParam(params, "sift_annotation", ""),
        sift_annotation_digest: _optionalBoundedParam(params, "sift_annotation_digest", ""),
        annotation_config_digest: _requiredBoundedParam(params, "annotation_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        somatic_annotation_options: _somaticAnnotationOptions(params.somatic_annotation_options),
        output_paths: output_paths,
    ]
}

def boundedSomaticMethylationAggregationEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "somatic_bedmethyl",
            "somatic_bedmethyl_index",
            "somatic_bigwig",
            "somatic_mod_summary",
            "somatic_dss_input_tsv",
            "somatic_methylation_aggregation_manifest",
            "somatic_methylation_aggregation_command_json",
            "somatic_methylation_aggregation_log",
            "somatic_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_somatic_methylation_aggregation.v1",
        entry_name: "somatic_methylation_aggregation",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["somatic_methylation_aggregation"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        analysis_intent_id: _requiredBoundedParam(params, "analysis_intent_id"),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        sample_role: _choice("sample_role", _requiredBoundedParam(params, "sample_role"), ["tumour", "normal", "control"] as Set),
        role_snapshot_digest: _requiredBoundedParam(params, "role_snapshot_digest"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        reference_genome_build: _requiredBoundedParam(params, "reference_genome_build"),
        role_aggregate_xam: _requiredBoundedParam(params, "role_aggregate_xam"),
        role_aggregate_xam_index: _requiredBoundedParam(params, "role_aggregate_xam_index"),
        role_aggregate_xam_digest: _requiredBoundedParam(params, "role_aggregate_xam_digest"),
        role_aggregate_xam_index_digest: _requiredBoundedParam(params, "role_aggregate_xam_index_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        modkit_config_digest: _requiredBoundedParam(params, "modkit_config_digest"),
        somatic_methylation_options_digest: _requiredBoundedParam(params, "somatic_methylation_options_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        somatic_methylation_options: _methylationOptions(params.somatic_methylation_options),
        output_paths: output_paths,
    ]
}

def boundedCnvEntryParams(params) {
    def mode = _choice(
        "cnv_mode",
        _requiredBoundedParam(params, "cnv_mode"),
        ["spectre", "qdnaseq"] as Set
    )
    def expected_outputs = [
        "cnv_vcf",
        "cnv_vcf_index",
        "cnv_manifest",
        "cnv_provenance",
        "qc_stats",
    ] as Set
    if (mode == "spectre") {
        expected_outputs += ["cnv_bed", "cnv_karyotype"] as Set
    }
    else {
        expected_outputs += ["cnv_segments_bed", "cnv_segments_vcf"] as Set
    }
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def options = _cnvOptions(params.cnv_options)
    if (!options.genome_build) {
        throw new IllegalArgumentException("CNV option 'genome_build' is required")
    }
    def aggregate_xam_kind = _choice(
        "aggregate_xam_kind",
        _optionalBoundedParam(params, "aggregate_xam_kind", "bam"),
        ["bam", "cram"] as Set
    )
    if (mode == "qdnaseq" && aggregate_xam_kind != "bam") {
        throw new IllegalArgumentException("cnv_mode 'qdnaseq' requires aggregate_xam_kind=bam; convert CRAM in a visible prerequisite task")
    }
    def entry = [
        entry_schema: "wf-human-variation.bounded_cnv.v1",
        entry_name: "cnv",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["cnv"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        aggregate_xam: _requiredBoundedParam(params, "aggregate_xam"),
        aggregate_xam_index: _requiredBoundedParam(params, "aggregate_xam_index"),
        aggregate_xam_kind: aggregate_xam_kind,
        aggregate_xam_digest: _requiredBoundedParam(params, "aggregate_xam_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        cnv_mode: mode,
        cnv_config_digest: _requiredBoundedParam(params, "cnv_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        cnv_options: options,
        output_paths: output_paths,
    ]
    if (mode == "spectre") {
        entry.snp_vcf = _requiredBoundedParam(params, "snp_vcf")
        entry.snp_vcf_index = _requiredBoundedParam(params, "snp_vcf_index")
        entry.snp_vcf_digest = _requiredBoundedParam(params, "snp_vcf_digest")
        entry.mosdepth_summary = _requiredBoundedParam(params, "mosdepth_summary")
        entry.mosdepth_regions = _requiredBoundedParam(params, "mosdepth_regions")
        entry.mosdepth_distribution = _requiredBoundedParam(params, "mosdepth_distribution")
        entry.mosdepth_thresholds = _requiredBoundedParam(params, "mosdepth_thresholds")
    }
    return entry
}

def boundedStrEntryParams(params) {
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        [
            "str_vcf",
            "str_vcf_index",
            "str_loci_tsv",
            "straglr_tsv",
            "stranger_tsv",
            "str_content_csv",
            "str_manifest",
            "str_provenance",
            "qc_stats",
        ] as Set
    )
    return [
        entry_schema: "wf-human-variation.bounded_str.v1",
        entry_name: "str",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["str"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        haplotagged_contig_manifest: _requiredBoundedParam(params, "haplotagged_contig_manifest"),
        haplotagged_contig_digest: _requiredBoundedParam(params, "haplotagged_contig_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        sex: _choice("sex", _requiredBoundedParam(params, "sex"), ["XX", "XY"] as Set),
        repeat_bed: _requiredBoundedParam(params, "repeat_bed"),
        variant_catalogue: _requiredBoundedParam(params, "variant_catalogue"),
        str_config_digest: _requiredBoundedParam(params, "str_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        str_options: _strOptions(params.str_options),
        output_paths: output_paths,
    ]
}

def boundedMethylationEntryParams(params) {
    def mode = _choice(
        "methylation_mode",
        _requiredBoundedParam(params, "methylation_mode"),
        ["unphased", "phased"] as Set
    )
    def expected_outputs = [
        "bedmethyl",
        "bigwig",
        "methylation_manifest",
        "methylation_provenance",
        "qc_stats",
    ] as Set
    def output_paths = _requireOutputPaths(
        _boundedOutputPaths(params.output_paths),
        expected_outputs
    )
    def entry = [
        entry_schema: "wf-human-variation.bounded_methylation.v1",
        entry_name: "methylation",
        task_family: _choice(
            "task_family",
            _requiredBoundedParam(params, "task_family"),
            ["methylation"] as Set
        ),
        task_key: _requiredBoundedParam(params, "task_key"),
        task_dir: _requiredBoundedParam(params, "task_dir"),
        task_cache_dir: _requiredBoundedParam(params, "task_cache_dir"),
        completion_marker_path: _requiredBoundedParam(params, "completion_marker_path"),
        sample_id: _requiredBoundedParam(params, "sample_id"),
        reference_id: _requiredBoundedParam(params, "reference_id"),
        methylation_mode: mode,
        aggregate_xam: _requiredBoundedParam(params, "aggregate_xam"),
        aggregate_xam_index: _requiredBoundedParam(params, "aggregate_xam_index"),
        aggregate_xam_digest: _requiredBoundedParam(params, "aggregate_xam_digest"),
        reference_fasta: _requiredBoundedParam(params, "reference_fasta"),
        reference_index: _requiredBoundedParam(params, "reference_index"),
        methylation_config_digest: _requiredBoundedParam(params, "methylation_config_digest"),
        container_digest: _requiredBoundedParam(params, "container_digest"),
        methylation_options: _methylationOptions(params.methylation_options),
        output_paths: output_paths,
    ]
    if (mode == "phased") {
        entry.haplotagged_xam = _requiredBoundedParam(params, "haplotagged_xam")
        entry.haplotagged_xam_index = _requiredBoundedParam(params, "haplotagged_xam_index")
        entry.haplotagged_xam_digest = _requiredBoundedParam(params, "haplotagged_xam_digest")
        entry.phased_prerequisite_policy = "block_or_controller_degrade_to_unphased"
    }
    else {
        entry.haplotagged_xam = ""
        entry.haplotagged_xam_index = ""
        entry.haplotagged_xam_digest = ""
        entry.phased_prerequisite_policy = "not_required"
    }
    return entry
}

def boundedEntryContractJson(Map entry) {
    return JsonOutput.prettyPrint(JsonOutput.toJson(entry))
}
