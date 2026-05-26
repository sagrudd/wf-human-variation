Maintenance
===========

Development Contract
--------------------

Documentation is part of the development contract. A behavior change is not
complete until the technical documentation and tests that describe that
behavior are updated.

Required documentation updates:

* architecture changes: update ``docs/architecture.rst``;
* ingress changes: update ``docs/ingress.rst``;
* shared controller or dynamic-runtime changes: update
  ``docs/workflow-control.rst``;
* analysis branch changes: update ``docs/subworkflows.rst``;
* parameter changes: update ``docs/parameters.rst``;
* dependency changes: update ``docs/dependencies.rst``;
* output changes: update ``docs/outputs.rst``;
* test strategy changes: update ``docs/testing.rst``;
* failure-mode changes: update ``docs/troubleshooting.rst``.

Review Focus
------------

Reviewers should check:

* whether global branch decisions changed;
* whether any feature flag silently activates another analysis family instead
  of declaring an explicit prerequisite;
* whether any channel operation introduces a new whole-run barrier;
* whether runtime state is written through manifest/event APIs rather than
  mutable ``params.wf[...]`` side effects;
* whether task provenance is present in the shared manifest, including tool
  versions, container digests, command arguments, input checksums, task status,
  and output artefacts;
* whether containers are referenced by immutable ``@sha256:`` digests and any
  source tag resolution has been recorded in the manifest;
* whether report-only dependencies such as ``ezcharts``, ``dominate``,
  ``bokeh``, or browser layout libraries have been kept out of maintained
  runtime surfaces;
* whether optional values are represented clearly;
* whether tool command options are structured allowlisted objects rather than
  free-form shell fragments;
* whether genome-build/reference compatibility remains centralised through
  ``lib/reference_compatibility.nf`` and shared controller manifest state;
* whether matching changes are needed in ``../gnostikon-workflow-control`` and
  ``../poikilognostikon``;
* whether a bounded entry has replaced a ``main.nf`` responsibility rather than
  expanding the monolithic graph;
* whether sample alias use remains consistent;
* whether output filenames and schema entries match;
* whether publication/export content still matches generated artefacts;
* whether docs and tests moved with the code.

Known Compatibility Debt
------------------------

* Static ``main.nf`` SNP activation for STR, phasing, and Spectre CNV.
* ``main.nf`` remains a compatibility reference for tool invocations, process
  wiring, and expected outputs until bounded entries retire each responsibility.
* The mapping bounded entry and sample aggregation bounded entry are the first
  real named execution units. Later family work must preserve their
  controller-owned params contracts, declared output paths, and
  completion-marker semantics rather than moving readiness back into the
  compatibility graph. The sample aggregation bounded entry owns
  machine-readable coverage QC and ``rejected_low_coverage`` state; this must
  not drift back into HTML reporting.
* QDNAseq format compatibility.
* Placeholder optional files outside the finite transitional list in
  ``docs/architecture.rst``.
* Any reintroduction of mutable ``params.wf[...]`` runtime side effects.
  Ingress run IDs must stay as per-sample artefacts or controller-owned
  manifest/event records.
* Provenance still scattered across legacy logs and ad hoc files rather than
  shared manifest task records.
* AWS Batch mirrored images need registry-specific digest values; do not fall
  back to tags when a mirror digest is missing.
* Any remaining free-form tool option pass-through outside the transitional
  rejection path for legacy ``*_args`` parameters.
* Drift between this workflow, ``gnostikon-workflow-control``, and
  Poikilognostikon migration records.
* Low-coverage behavior: rejected samples must use ``rejected_low_coverage``
  and must not appear as successful workflow completions.
* Basecaller model detection.
* Annotation, CNV, STR, and publication genome-build restrictions.
* Partner export placeholder handling.
* Publication joins over multiple channels.

Release Hygiene
---------------

Before release:

1. Build Sphinx docs with warnings as errors.
2. Run available workflow smoke tests.
3. Confirm parameter schema and README agree with behavior.
4. Confirm output definitions match produced artefacts.
5. Record any known unverified paths.
