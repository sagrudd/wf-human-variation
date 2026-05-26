/*
 * Optional-input helpers for the transitional Nextflow boundary.
 *
 * Shared controller code models optional values as typed present/absent state
 * in gnostikon-workflow-control. This workflow may still need concrete files or
 * empty channels at process boundaries, but placeholder semantics should be
 * created through these helpers rather than spread through workflow logic.
 */

def optionalBoundaryFile() {
    return file("${projectDir}/data/OPTIONAL_FILE")
}

def optionalBoundaryChannel() {
    return Channel.fromPath("${projectDir}/data/OPTIONAL_FILE", checkIfExists: true)
}

def optionalBoundaryPath(String name) {
    return file("OPTIONAL_FILE.${name}")
}

def isOptionalBoundaryFile(def value) {
    if (value == null) {
        return true
    }
    return value.name == "OPTIONAL_FILE" || value.name.startsWith("OPTIONAL_FILE.")
}

def realOptionalArg(def value, String option) {
    return isOptionalBoundaryFile(value) ? "" : "${option} ${value}"
}
