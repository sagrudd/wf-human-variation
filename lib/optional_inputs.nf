/*
 * Optional-input helpers for the transitional Nextflow boundary.
 *
 * Shared controller code models optional values as typed present/absent state
 * in gnostikon-workflow-control. This workflow may still need concrete files or
 * empty channels at process boundaries, but absent-input semantics should be
 * created through these helpers rather than spread through workflow logic.
 */

def absentInputPrefix() {
    return "__wf_human_variation_absent_input__"
}

def optionalBoundaryFile(String name = "file") {
    def boundaryDir = new File("${workflow.workDir}/optional-input-boundary")
    boundaryDir.mkdirs()

    def boundaryFile = new File(boundaryDir, "${absentInputPrefix()}.${name}")
    if (!boundaryFile.exists()) {
        boundaryFile.text = ""
    }
    return file(boundaryFile.toString())
}

def optionalBoundaryChannel() {
    return Channel.of(optionalBoundaryFile())
}

def optionalBoundaryPath(String name) {
    return optionalBoundaryFile(name)
}

def isOptionalBoundaryFile(def value) {
    if (value == null) {
        return true
    }
    return value.name == absentInputPrefix() || value.name.startsWith("${absentInputPrefix()}.")
}

def realOptionalArg(def value, String option) {
    return isOptionalBoundaryFile(value) ? "" : "${option} ${value}"
}
