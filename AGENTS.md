# Agent Instructions

This repository is the `wf-human-variation` workflow fork. Work here must stay
focused on understanding, maintaining, testing, and improving this workflow.

## Documentation Contract

- The canonical technical documentation lives in `docs/` and is built with
  Sphinx for Read the Docs.
- Do not restore the legacy Markdown fragment documentation that previously
  lived in `docs/01_*.md` through `docs/12_*.md`.
- Do not add Poikilognostikon product, runtime, or migration-plan
  documentation to this repository's `docs/` tree. Keep this documentation
  specific to `wf-human-variation`.
- Any workflow behavior change must update the relevant Sphinx documentation in
  the same change set.
- Documentation must explain maintenance-relevant behavior, not just user
  invocation. Include inputs, outputs, task dependencies, hidden coupling,
  failure modes, tests, and operational caveats.
- Treat documentation as part of the development contract. A code change that
  changes behavior but leaves stale technical documentation is incomplete.

## Maintenance Rules

- Preserve useful upstream workflow behavior deliberately; do not carry forward
  accidental behavior without documenting it.
- Keep sample identity, aliases, barcodes, and read-group names distinct in
  explanations and code comments.
- When changing workflow parameters, update `nextflow_schema.json`,
  `nextflow.config`, and `docs/parameters.rst` together.
- When changing outputs, update `output_definition.json` and
  `docs/outputs.rst` together.
- When changing workflow structure, update `docs/architecture.rst`,
  `docs/subworkflows.rst`, and `docs/maintenance.rst` as needed.
- Every new or refactored bounded task must have a deterministic task key,
  deterministic task-cache output paths, and a `.gnostikon_task_complete.json`
  marker written only after required outputs exist. Update `docs/idempotency.rst`
  and tests when changing this contract.
- The top-level bounded task families are `basecalling`, `mapping`,
  `sample_aggregation`, `variant_calling`, `methylation`, `cnv`, `str`, and
  `reporting`. Do not add another top-level family without updating
  `docs/bounded-task-families.rst`, `lib/task_families.nf`, and the shared
  controller registry in `../gnostikon-workflow-control`.
- Do not grow `main.nf` as the scheduler for new dynamic behavior. New dynamic
  work should be a bounded Nextflow entry launched by the Python controller via
  `gnostikon-workflow-control nextflow-task`.
- Do not encode feature booleans that implicitly activate other analysis
  families. STR, Spectre CNV, phased methylation, and similar cases must
  declare explicit task prerequisites using the contract in
  `docs/explicit-prerequisites.rst` and `lib/feature_prerequisites.nf`.
- New bounded entries must not use global `.collect()` or broad unkeyed
  `.combine()` for readiness. Use keyed per-sample/per-reference joins as
  documented in `docs/keyed-joins.rst` and `lib/keyed_joins.nf`.
- Prefer small, reviewable changes with focused tests.
