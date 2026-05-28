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
  replace the current filename label behavior of ``--sample_name``.
  Identity-sensitive caller arguments and metrics metadata use ``--sample_id``;
  current output filenames use ``--sample_name``/``meta.alias`` for
  compatibility.
* ``--bed``: target regions for variant calling and optional coverage summary.
* ``--coverage_bed``: regions for coverage metrics only.

Reference Compatibility
-----------------------

CNV, STR, and annotation paths require a validated human genome build. The
compatibility graph centralises this through ``lib/reference_compatibility.nf``
and ``validateReferenceCompatibility`` rather than scattering separate checks
across SNP, CNV, STR, annotation, and export code.

STR currently requires hg38-compatible reference state. Annotation and CNV
paths accept hg19 or hg38. Bounded controller-launched work should mirror this
policy with ``gnostikon-workflow-control validate-reference-compatibility``.

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
``rejected_low_coverage``. The workflow status remains non-zero for the
rejected sample.

Poikilognostikon maps this sample state into somatic role states before
scheduling bounded somatic work: ``tumour_rejected_low_coverage``,
``normal_rejected_low_coverage``, and paired
``somatic_pair_blocked_low_coverage``. These are controller states rather than
workflow report products.

HTML Reporting
--------------

Workflow-generated EPI2ME HTML reports are not part of the ``humvar3`` public
contract. The legacy ``--output_report`` and
``--alignment_report_coverage_threshold`` parameters have been removed from
configuration, schema, documentation, and output declarations. Operator
dashboards and API views are expected to be built by Poikilognostikon from the
shared runtime manifest and machine-readable workflow artefacts.

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
* ``--spectre_options``: allowlisted Spectre keys such as ``min_cnv_len``;
* ``--clairs_options``: allowlisted paired ClairS keys such as ``threads``,
  ``chunk_num``, ``chunk_size``, ``ctg_name``, ``include_all_ctgs``,
  ``enable_phasing``, ``min_af``, ``indel_min_af``, ``min_bq``,
  ``min_coverage``, ``platform``, ``qual``, ``show_ref``, and
  ``show_germline``;
* ``--clairs_to_options``: allowlisted ClairS-TO keys such as ``threads``,
  ``chunk_size``, ``ctg_name``, ``include_all_ctgs``, ``min_af``,
  ``min_coverage``, ``qual``, ``show_ref``, and ``debug``;
* ``--severus_options``: allowlisted Severus keys such as ``threads``,
  ``min_sv_length``, ``min_support``, ``vaf_threshold``, ``single_bp``,
  ``resolve_overlaps``, and ``between_junction_ins``.
* ``--dss_options``: allowlisted DSS keys such as ``threads``,
  ``equal_disp``, ``smoothing``, ``smoothing_span``, ``delta``,
  ``p_threshold``, ``minlen``, ``min_cg``, ``dis_merge``, and ``pct_sig``.

For controller-launched somatic entries, the structured option object also has
a controller-owned digest. ``clairs_to_options_digest``,
``clairs_options_digest``, ``severus_options_digest``, and
``somatic_methylation_options_digest`` and ``dss_options_digest`` are part of
the bounded task key, manifest, and provenance so option changes cannot reuse
stale completion markers.

Every option that changes a tool command must be represented in the bounded
task key and provenance. Adding a new tool option requires updating
``nextflow_schema.json``, ``lib/tool_options.nf``, and the shared
``gnostikon-workflow-control`` allowlist together.

Basecaller Model Metadata
-------------------------

Basecaller-to-Clair3 compatibility is maintained in
``data/clair3_models.tsv``. User-facing basecaller parameter choices are
maintained in ``nextflow_schema.json``.

Do not regenerate the schema from container contents. The legacy
``util/update_models_schema.sh`` helper is deprecated and exits without
changing files. Model support changes must be reviewed as explicit source edits
so workflow behavior, schema, and release notes can be checked together.

Container Digests
-----------------

Container references in ``base.config`` must use immutable ``image@sha256:``
syntax. The SHA-like values retained under ``params.wf.*_tag`` are source tags
for release provenance only; they must not be used as runtime container pins.

When a tag is resolved to a digest, record the mapping in the shared manifest
with ``gnostikon-workflow-control record-container-digest``. Mirrored registries
such as AWS Batch must provide their own digest values. Missing mirror digests
should block execution rather than falling back to tags.

Runtime dependency policy is documented in ``docs/dependencies.rst``.

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
