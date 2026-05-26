Architecture
============

Top-Level Flow
--------------

The imported compatibility entry point, ``main.nf``, performs the following
broad steps:

1. Validate selected parameter combinations.
2. Prepare the reference.
3. Ingress and, when needed, align or realign the input XAM.
4. Compute alignment statistics and coverage.
5. Apply coverage gating and optional downsampling.
6. Infer or accept sample sex when required.
7. Run enabled analysis branches.
8. Combine metrics, generate reports, package browser outputs, and publish
   selected artefacts.

This is one launch-time graph. It is not the target dynamic runtime scheduler.
New ``humvar3`` work should be implemented as controller-launched bounded
entries, as described in ``docs/controller-execution.rst``.

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
