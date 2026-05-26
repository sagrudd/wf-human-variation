Architecture
============

Top-Level Flow
--------------

The imported compatibility entry point, ``main.nf``, performs the following
broad steps:

1. Validate selected parameter combinations.
2. Prepare the reference.
3. Ingress and, when needed, align or realign the input XAM.
4. Compute reusable reference/genome-build compatibility when requested
   branches require restricted builds.
5. Compute alignment statistics and coverage.
6. Apply coverage gating and optional downsampling. Low-coverage inputs become
   ``rejected_low_coverage`` and intentionally fail the run after optional
   report generation.
7. Infer or accept sample sex when required.
8. Run enabled analysis branches.
9. Combine metrics, generate reports, package browser outputs, and publish
   selected artefacts.

This is one launch-time graph. It is not the target dynamic runtime scheduler.
Keep it initially as a reference for exact tool invocations, process wiring,
and expected output artefacts. New ``humvar3`` work should progressively move
those contracts into controller-launched bounded entries, as described in
``docs/controller-execution.rst``.

``main.nf`` Retirement Rule
---------------------------

When a bounded entry replaces imported behavior:

1. record the source ``main.nf`` process or subworkflow path that was mined;
2. preserve the relevant tool command shape and expected outputs in the bounded
   contract;
3. add focused tests for the new bounded behavior;
4. update documentation to show the new controller-launched boundary;
5. mark the old ``main.nf`` responsibility as compatibility debt until it is
   no longer required for transitional launches.

Do not add new dynamic readiness, multi-sample scheduling, or runtime manifest
state to ``main.nf``. That work belongs in the controller and bounded entries.

Global Branch Decisions
-----------------------

Several high-impact decisions are made once in ``main.nf``:

* ``run_haplotagging = params.str || params.phased``;
* ``convert_cram_to_bam = params.cnv && params.use_qdnaseq``;
* ``run_snp = params.snp || run_haplotagging || (params.cnv &&
  !params.use_qdnaseq)``;
* genome-build enforcement for CNV, STR, and annotated SNP/SV/phased work;
* partner export activation from ``params.partner``.

These decisions are compatibility debt because one visible flag can enable
additional work. Do not reproduce them in bounded entries. New work must use
the explicit prerequisite contract in ``docs/explicit-prerequisites.rst`` and
``lib/feature_prerequisites.nf``. Document any compatibility-graph change in
``docs/subworkflows.rst`` and ``docs/parameters.rst``.

Reference Compatibility
-----------------------

Genome-build and reference compatibility must be treated as one reusable
validation stage. In the imported graph, ``lib/reference_compatibility.nf``
decides which capabilities require validation and
``validateReferenceCompatibility`` emits the detected ``genome_build`` for SNP,
CNV, STR, annotation, sex inference, and reporting consumers.

New bounded entries should record the same state through
``gnostikon-workflow-control validate-reference-compatibility`` instead of
duplicating hg19/hg38 checks in individual task families.

Whole-Run Barriers
------------------

The workflow uses channel operations such as ``collect()``, ``combine()``,
``first()``, and ``groupTuple()`` for several aggregation steps. These can make
otherwise local work wait for broader channel completion.

When changing the imported compatibility graph, explicitly check whether the
change adds or removes a whole-run barrier. New bounded entries must instead
use the keyed rules in ``docs/keyed-joins.rst``: per-sample joins use
``sample_id``, per-reference joins use ``sample_id`` plus ``reference_id``, and
task readiness uses ``task_key``.

Placeholder Optionality
-----------------------

The workflow currently uses placeholder files such as ``data/OPTIONAL_FILE`` in
several places to satisfy Nextflow input shapes. Treat these as compatibility
mechanisms, not as a design pattern to extend. New optional behavior should be
represented with explicit channel branching, optional outputs, or documented
schema state wherever possible.

The shared controller package represents optional inputs as typed present or
absent state. This workflow may still materialise a placeholder file at a
Nextflow process boundary, but those placeholders must be routed through
``lib/optional_inputs.nf`` where practical and documented as transitional
boundary behavior. Do not pass ``OPTIONAL_FILE`` semantics back into controller
events, manifests, or task-planning state.

Task Reuse
----------

The ``humvar3`` migration requires bounded task families that can be skipped
when equivalent successful work already exists. New or refactored task families
must use deterministic task keys, task-cache output paths, and completion
markers as described in ``docs/idempotency.rst``. Existing Nextflow work
directories and published output filenames are not sufficient reuse contracts.

The top-level family split is fixed in ``docs/bounded-task-families.rst``:
basecalling, mapping, per-sample aggregation, variant calling, methylation,
CNV, STR, and reporting. Keep supporting operations inside those families unless
the shared controller registry is deliberately changed.

Dynamic Runtime Direction
-------------------------

The intended Poikilognostikon direction is a multi-sample runtime where sample,
POD5, BAM, task, and channel-closure state can arrive dynamically. The current
workflow still contains the imported compatibility graph, but new bounded work
must use Nextflow only for task execution. Relevant controller contracts live in
``../gnostikon-workflow-control`` and are documented for this workflow in
``docs/workflow-control.rst`` and ``docs/controller-execution.rst``.

Mutable ``params.wf[...]`` updates in the imported graph are compatibility
debt. New bounded work must emit manifest/event writes through
``gnostikon-workflow-control`` instead; ``lib/runtime_manifest_events.nf``
contains the transitional command helpers for this boundary.
