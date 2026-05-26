process writeBoundedEntryContract {
    label "wf_common"
    tag "${entry.task_family}:${entry.task_key}"

    input:
        val entry
        val contract_json

    output:
        path "bounded-entry-contract.json", emit: contract

    script:
    """
    set -euo pipefail

    cat > bounded-entry-contract.json <<'JSON'
${contract_json}
JSON

    python3 - <<'PY'
import datetime
import json
from pathlib import Path

contract_path = Path("bounded-entry-contract.json")
contract = json.loads(contract_path.read_text())
output_path = Path(contract["output_paths"]["bounded_launch_contract"])
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(contract, indent=2, sort_keys=True) + "\\n")

marker_path = Path(contract["completion_marker_path"])
marker_path.parent.mkdir(parents=True, exist_ok=True)
marker = {
    "marker_schema": "gnostikon.task_completion.v1",
    "task_key": contract["task_key"],
    "task_family": contract["task_family"],
    "status": "succeeded",
    "completed_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "outputs": [
        {
            "kind": "bounded_launch_contract",
            "path": str(output_path),
            "required": True,
        }
    ],
    "metadata": {
        "analysis_status": "not_implemented_scaffold",
        "bounded_entry": contract["entry_name"],
        "entry_schema": contract["entry_schema"],
    },
}
tmp = marker_path.with_suffix(marker_path.suffix + ".tmp")
tmp.write_text(json.dumps(marker, indent=2, sort_keys=True) + "\\n")
tmp.replace(marker_path)
PY
    """
}
