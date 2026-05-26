import groovy.json.JsonSlurper

/*
 * Structured allowlisted tool option rendering for legacy process boundaries.
 *
 * New controller-owned task contracts should render options in
 * gnostikon-workflow-control. These helpers keep transitional Nextflow entries
 * from interpolating free-form shell fragments while the bounded task families
 * are migrated.
 */

def toolOptionAllowlist() {
    return [
        sniffles: [
            mosaic: [flag: "--mosaic", type: "boolean"],
            min_support: [flag: "--minsupport", type: "integer"],
            minsvlen: [flag: "--minsvlen", type: "integer"],
        ],
        modkit: [
            combine_strands: [flag: "--combine-strands", type: "boolean"],
            cpg: [flag: "--cpg", type: "boolean"],
            preset: [flag: "--preset", type: "enum", choices: ["traditional"]],
        ],
        spectre: [
            min_cnv_len: [flag: "--min-cnv-len", type: "integer"],
        ],
    ]
}

def parseToolOptions(String tool, Object options, Object legacyArgs = null) {
    if (legacyArgs != null && legacyArgs.toString().trim()) {
        throw new IllegalArgumentException(
            "${tool}_args is no longer supported; use structured ${tool}_options instead."
        )
    }
    if (options == null) {
        return [:]
    }
    if (options instanceof Map) {
        return options
    }
    String text = options.toString().trim()
    if (!text) {
        return [:]
    }
    def parsed = new JsonSlurper().parseText(text)
    if (!(parsed instanceof Map)) {
        throw new IllegalArgumentException("${tool}_options must be a JSON object or map.")
    }
    return parsed
}

def renderToolOptions(String tool, Object options, Object legacyArgs = null) {
    def allowlist = toolOptionAllowlist()[tool]
    if (allowlist == null) {
        throw new IllegalArgumentException("Unsupported structured option target: ${tool}")
    }
    Map parsed = parseToolOptions(tool, options, legacyArgs)
    def unknown = parsed.keySet().findAll { !allowlist.containsKey(it.toString()) }.sort()
    if (unknown) {
        throw new IllegalArgumentException("${tool}_options contains non-allowlisted key(s): ${unknown.join(', ')}")
    }
    def rendered = []
    parsed.keySet().collect { it.toString() }.sort().each { key ->
        def spec = allowlist[key]
        def value = parsed[key]
        if (spec.type == "boolean") {
            if (!(value instanceof Boolean)) {
                throw new IllegalArgumentException("${tool}_options.${key} must be a boolean.")
            }
            if (value) {
                rendered << spec.flag
            }
        }
        else if (spec.type == "integer") {
            if (!(value instanceof Number) || value instanceof Boolean || value.toInteger() < 0) {
                throw new IllegalArgumentException("${tool}_options.${key} must be a non-negative integer.")
            }
            rendered << spec.flag
            rendered << value.toInteger().toString()
        }
        else if (spec.type == "enum") {
            String normalized = value.toString()
            if (!spec.choices.contains(normalized)) {
                throw new IllegalArgumentException("${tool}_options.${key} must be one of: ${spec.choices.join(', ')}")
            }
            rendered << spec.flag
            rendered << normalized
        }
        else {
            throw new IllegalArgumentException("Unsupported option type for ${tool}.${key}: ${spec.type}")
        }
    }
    return rendered.collect { shellQuote(it) }.join(" ")
}

def shellQuote(Object value) {
    String text = value.toString()
    if (text ==~ /[A-Za-z0-9_.,:\/=@%+-]+/) {
        return text
    }
    return "'" + text.replace("'", "'\"'\"'") + "'"
}
