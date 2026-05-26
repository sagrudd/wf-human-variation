/*
 * Shell command helpers for controller-owned manifest/event writes.
 *
 * Bounded entries must not mutate params.wf for runtime state. They should use
 * gnostikon-workflow-control so manifest changes and runtime events stay
 * append-only and replayable.
 */

def recordIngressRunIdsCommand(String manifest, List runIds, String eventDir = "", String eventStore = "") {
    if (!manifest) {
        throw new IllegalArgumentException("recordIngressRunIdsCommand requires manifest")
    }
    def cleaned = runIds.findAll { it != null && it.toString().trim() }.collect { it.toString().trim() }.unique()
    if (!cleaned) {
        throw new IllegalArgumentException("recordIngressRunIdsCommand requires at least one run id")
    }
    def command = ["gnostikon-workflow-control", "record-ingress-runids", "--manifest", manifest]
    cleaned.each { command += ["--run-id", it] }
    if (eventDir) {
        command += ["--event-dir", eventDir]
    }
    if (eventStore) {
        command += ["--event-store", eventStore]
    }
    return command.join(" ")
}

def recordTaskProvenanceCommand(String manifest, String provenanceJson, String eventDir = "", String eventStore = "") {
    if (!manifest) {
        throw new IllegalArgumentException("recordTaskProvenanceCommand requires manifest")
    }
    if (!provenanceJson) {
        throw new IllegalArgumentException("recordTaskProvenanceCommand requires provenanceJson")
    }
    def command = [
        "gnostikon-workflow-control",
        "record-task-provenance",
        "--manifest",
        manifest,
        "--provenance-json",
        provenanceJson
    ]
    if (eventDir) {
        command += ["--event-dir", eventDir]
    }
    if (eventStore) {
        command += ["--event-store", eventStore]
    }
    return command.join(" ")
}

def recordContainerDigestCommand(
    String manifest,
    String label,
    String image,
    String tag,
    String digest,
    String eventDir = "",
    String eventStore = ""
) {
    if (!manifest) {
        throw new IllegalArgumentException("recordContainerDigestCommand requires manifest")
    }
    if (!label || !image || !tag || !digest) {
        throw new IllegalArgumentException("recordContainerDigestCommand requires label, image, tag, and digest")
    }
    def command = [
        "gnostikon-workflow-control",
        "record-container-digest",
        "--manifest",
        manifest,
        "--label",
        label,
        "--image",
        image,
        "--tag",
        tag,
        "--digest",
        digest
    ]
    if (eventDir) {
        command += ["--event-dir", eventDir]
    }
    if (eventStore) {
        command += ["--event-store", eventStore]
    }
    return command.join(" ")
}
