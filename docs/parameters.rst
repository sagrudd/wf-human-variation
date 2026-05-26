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
