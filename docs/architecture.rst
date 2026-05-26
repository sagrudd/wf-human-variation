Architecture
============

Top-Level Flow
--------------

``main.nf`` performs the following broad steps:

1. Validate selected parameter combinations.
2. Prepare the reference.
3. Ingress and, when needed, align or realign the input XAM.
4. Compute alignment statistics and coverage.
5. Apply coverage gating and optional downsampling.
6. Infer or accept sample sex when required.
7. Run enabled analysis branches.
8. Combine metrics, generate reports, package browser outputs, and publish
   selected artefacts.

This is one launch-time graph. It is not a dynamic runtime scheduler.

Global Branch Decisions
-----------------------

Several high-impact decisions are made once in ``main.nf``:

* ``run_haplotagging = params.str || params.phased``;
* ``convert_cram_to_bam = params.cnv && params.use_qdnaseq``;
* ``run_snp = params.snp || run_haplotagging || (params.cnv &&
  !params.use_qdnaseq)``;
* genome-build enforcement for CNV, STR, and annotated SNP/SV/phased work;
* partner export activation from ``params.partner``.

These decisions are maintenance-sensitive because they mean one visible flag
can enable additional work. Document any change to these relationships in
``docs/subworkflows.rst`` and ``docs/parameters.rst``.

Whole-Run Barriers
------------------

The workflow uses channel operations such as ``collect()``, ``combine()``,
``first()``, and ``groupTuple()`` for several aggregation steps. These can make
otherwise local work wait for broader channel completion.

When changing any channel topology, explicitly check whether the change adds or
removes a whole-run barrier. Record intentional barriers in this document.

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

Dynamic Runtime Direction
-------------------------

The intended Poikilognostikon direction is a multi-sample runtime where sample,
POD5, BAM, task, and channel-closure state can arrive dynamically. The current
workflow does not yet implement that runtime model. Relevant controller
contracts live in ``../gnostikon-workflow-control`` and are documented for this
workflow in ``docs/workflow-control.rst``.
