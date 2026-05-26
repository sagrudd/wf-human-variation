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
    def output_paths = raw.collectEntries { key, value ->
        if (value == null || value.toString().trim() == "") {
            throw new IllegalArgumentException("bounded output path '${key}' is empty")
        }
        [(key.toString()): value.toString()]
    }
    def supported_outputs = ["bounded_launch_contract"] as Set
    if (output_paths.keySet() != supported_outputs) {
        throw new IllegalArgumentException(
            "task 14 bounded scaffold supports only output_paths.bounded_launch_contract; " +
            "analysis outputs must be added by the family implementation task"
        )
    }
    return output_paths.sort()
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

def boundedEntryContractJson(Map entry) {
    return JsonOutput.prettyPrint(JsonOutput.toJson(entry))
}
