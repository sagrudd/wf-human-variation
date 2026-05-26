#!/usr/bin/env bash
# Deprecated compatibility shim.
#
# Model metadata and parameter schema changes must be reviewed as explicit
# source edits. Do not regenerate nextflow_schema.json from container contents.
set -euo pipefail

cat >&2 <<'EOF'
util/update_models_schema.sh is deprecated and intentionally does not mutate
nextflow_schema.json.

Update model support deliberately instead:

1. Edit data/clair3_models.tsv for basecaller-to-Clair3 compatibility.
2. Edit nextflow_schema.json for user-facing parameter enums/help text.
3. Review both files together and run the documented release gates.

Container-driven schema generation is not a maintained workflow-control
contract for humvar3.
EOF

exit 64
