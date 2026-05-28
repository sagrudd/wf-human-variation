Dependencies
============

Runtime Dependency Policy
-------------------------

``humvar3`` has no maintained local Python package manifest for workflow
runtime dependencies. Python helpers run inside the pinned runtime containers
declared in ``base.config``. The only local requirements file is
``docs/requirements.txt``, which is scoped to Sphinx documentation builds.

Report-only Python dependencies are not part of the maintained workflow
surface. Do not add dependencies such as ``ezcharts``, ``dominate``, ``bokeh``,
or browser/report layout libraries unless a future non-report task documents a
specific retained runtime purpose.

Retained Python Dependencies
----------------------------

The retained Python helpers currently use:

* ``pandas`` and ``numpy`` for machine-readable metrics, coverage summaries,
  downsampling decisions, and STR content extraction;
* ``pysam`` for BAM/CRAM/reference validation and STR content extraction;
* ``natsort`` for BED sanitisation.

These dependencies support validation or machine-readable artefacts. They must
not be treated as report dependencies merely because the old report generators
also used tabular metrics.

Somatic ClairS-TO Runtime
-------------------------

The bounded ``somatic_tumour_only_snv`` entry requires an owned ClairS-TO
runtime image, not the inherited ONT ``ontresearch/clairs-to`` source image.
The runtime must expose ``run_clairs_to`` on ``PATH`` and record version probes
for ClairS-TO, Python, PyPy, GNU parallel, and the HTS tools used to compress
and index final VCFs.

The controller must provide:

* ``clairs_to_model`` as the versioned model directory staged into the task;
* ``clairs_to_model_name`` when the model directory basename is not the
  ClairS-TO ``--platform`` value;
* ``clairs_to_database_bundle`` as the explicit replacement for inherited
  container-local ``CLAIR_DBS_PATH`` assets;
* SHA-256 digests for the model, model table, database bundle, configuration,
  reference, aggregate XAM/index, and runtime container.

Do not claim ARM64 support for this entry until the owned image has
``linux/arm64`` build evidence, immutable digest launches, and method-level
concordance evidence for the selected model/database bundle.

Somatic Severus Runtime
-----------------------

Bounded ``somatic_tumour_only_sv`` and ``somatic_paired_sv`` entries require
an owned Severus runtime image, not the inherited ONT
``ontresearch/wf-somatic-sv`` source image. The runtime must expose
``severus`` on ``PATH`` and record version probes for Severus, Python, native
Python dependencies such as ``pysam`` and ``numpy``, and the HTS tools used to
compress, sort, and index final VCFs.

The controller must provide explicit reference-compatible state for optional
PON, TRF/VNTR BED, and segmental-duplication BED assets. Ready asset states
must include asset kind, path, SHA-256 checksum, genome build, and source
evidence. Missing optional assets must be recorded as
``optional_not_provided``. Hidden inherited container defaults under
``WFSV_PON_PATH`` or ``WFSV_TRBED_PATH``, and hardcoded ``hg38.segdups`` /
``SEG_DUP`` annotation fallbacks, are not release evidence.

Somatic DSS Runtime
-------------------

Bounded ``somatic_differential_methylation`` requires an owned DSS/R runtime
image, not inherited report-era containers. The runtime must expose
``Rscript`` and the R packages ``DSS``, ``bsseq``, and ``data.table``. The
controller must provide ``dss_config_digest``, ``dss_options_digest``,
``r_bioconductor_lock_digest``, and immutable container digest evidence for
each launch. The bounded entry records ``somatic_r_versions`` at runtime so
operator review can compare the executed R package set with the declared lock
digest.

Do not claim ARM64 support for paired DSS until the owned image has
``linux/arm64`` build evidence and paired differential methylation concordance
evidence. DSS remains memory-intensive; resource changes must be captured as
structured ``dss_options`` and not as free-form R or shell arguments.

Container References
--------------------

Runtime containers are pinned by immutable OCI digest in ``base.config``.
The inherited containers may still contain packages that are no longer used by
``humvar3`` after report and browser removal. This repository does not contain
the container build recipes needed to safely rebuild those images in place.

When container contents are changed, update the relevant digest in
``base.config`` and record the source tag to digest mapping through the shared
manifest provenance path. Do not fall back to SHA-like tags or mutable image
tags to make dependency cleanup appear complete.

Maintenance Checks
------------------

Dependency changes must verify:

1. no retained workflow command imports ``ezcharts``, ``dominate``, ``bokeh``,
   or report/browser layout modules;
2. ``workflow-glue`` no longer exposes report, IGV, or JBrowse commands;
3. retained metrics and validation commands still import;
4. Sphinx documentation builds with warnings as errors;
5. any container digest changes are recorded in the workflow and manifest
   provenance contract.
