Parameters
==========

Sources Of Truth
----------------

Parameter defaults and schema are maintained in:

* ``nextflow.config``;
* ``nextflow_schema.json``.

This page explains maintenance obligations and important parameter groups. It
does not replace the JSON schema.

Workflow Selection
------------------

Top-level analysis flags:

* ``--snp``
* ``--sv``
* ``--cnv``
* ``--str``
* ``--mod``

Supporting or modifying flags include:

* ``--phased``
* ``--use_qdnaseq``
* ``--sv_benchmark``
* ``--annotation``
* ``--output_report``
* ``--igv``
* ``--partner``

Input And Reference
-------------------

Primary input parameters:

* ``--bam``: input BAM, CRAM, uBAM, or compatible directory.
* ``--ref``: reference FASTA.
* ``--sample_name``: display label used for current workflow outputs.
* ``--sample_id``: mandatory stable sample identity supplied by the workflow
  controller.
* ``--project``, ``--flowcell``, and ``--run_id``: optional context supplied by
  the workflow controller. These fields are metadata for migration and do not
  replace the current filename/report label behavior of ``--sample_name``.
* ``--bed``: target regions for variant calling and optional coverage summary.
* ``--coverage_bed``: regions for coverage reporting only.

Coverage And QC
---------------

Coverage behavior is controlled by:

* ``--bam_min_coverage``;
* ``--downsample_coverage``;
* ``--downsample_coverage_target``;
* ``--downsample_coverage_margin``;
* ``--depth_window_size``;
* ``--depth_intervals``.

When changing coverage semantics, update troubleshooting and output
documentation because low-coverage behavior affects user interpretation.
Inputs below ``--bam_min_coverage`` are represented as
``rejected_low_coverage``. A report can be emitted when ``--output_report`` is
enabled, but the workflow status remains non-zero for the rejected sample.

Structured Tool Options
-----------------------

Free-form shell option pass-throughs are not part of the ``humvar3`` contract.
The legacy ``--sniffles_args``, ``--modkit_args``, and ``--spectre_args``
surfaces are rejected by the transitional Nextflow helpers. Use structured
objects instead:

* ``--sniffles_options``: allowlisted Sniffles keys such as ``mosaic``,
  ``min_support``, and ``minsvlen``;
* ``--modkit_options``: allowlisted modkit keys such as ``combine_strands``,
  ``cpg``, and ``preset``;
* ``--spectre_options``: allowlisted Spectre keys such as ``min_cnv_len``.

Every option that changes a tool command must be represented in the bounded
task key and provenance. Adding a new tool option requires updating
``nextflow_schema.json``, ``lib/tool_options.nf``, and the shared
``gnostikon-workflow-control`` allowlist together.

Container Digests
-----------------

Container references in ``base.config`` must use immutable ``image@sha256:``
syntax. The SHA-like values retained under ``params.wf.*_tag`` are source tags
for release provenance only; they must not be used as runtime container pins.

When a tag is resolved to a digest, record the mapping in the shared manifest
with ``gnostikon-workflow-control record-container-digest``. Mirrored registries
such as AWS Batch must provide their own digest values. Missing mirror digests
should block execution rather than falling back to tags.

Maintenance Checklist
---------------------

For any parameter addition, removal, rename, or default change:

1. Update ``nextflow.config``.
2. Update ``nextflow_schema.json``.
3. Update this page.
4. Update any affected subworkflow documentation.
5. Add or update tests for the parameter interaction.
6. Check generated help output.

For hidden or UI-specific parameters, document the maintenance reason. Hidden
does not mean undocumented.
