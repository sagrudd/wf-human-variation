Bounded Task Families
=====================

``humvar3`` splits the imported workflow into eight top-level bounded task
families. This is the maintenance boundary for dynamic, multi-sample runtime
work. Supporting operations should be owned by one of these families rather
than becoming additional global branches.

Family Table
------------

Each family should become a controller-launched bounded Nextflow entry or a
small wrapper invoked by the controller. The controller decides when to launch,
skip, or force-refresh the family; the Nextflow entry only executes the bounded
unit it was given.

.. list-table::
   :header-rows: 1

   * - Family
     - Scope
     - Owns
   * - ``basecalling``
     - sample, run, POD5 batch
     - POD5-to-BAM conversion and basecalling metrics.
   * - ``mapping``
     - sample, input artefact, reference
     - BAM/CRAM/uBAM ingress, conversion, mapping, remapping, and mapping
       metrics.
   * - ``sample_aggregation``
     - sample, reference
     - Per-sample aggregate XAM refresh, read statistics, coverage QC, and
       low-coverage state from ready mapped chunks.
   * - ``variant_calling``
     - sample, reference, variant mode
     - SNP, SV, phasing, haplotagging, and variant annotation products.
   * - ``methylation``
     - sample, reference, methylation mode
     - Modified-base validation, modkit outputs, phased and unphased methylation
       products.
   * - ``cnv``
     - sample, reference, CNV mode
     - Spectre and QDNAseq copy-number outputs.
   * - ``str``
     - sample, reference
     - STR genotyping from haplotagged contig BAMs and sex state.
   * - ``reporting``
     - sample or project, publication family
     - Machine-readable QC publication, manifest projections, partner export,
       and publication from any explicitly completed subset of requested
       families.

Dependency Shape
----------------

The normal dynamic dependency shape is:

.. code-block:: text

   basecalling -> mapping -> sample_aggregation
   sample_aggregation -> variant_calling
   sample_aggregation -> methylation
   sample_aggregation -> cnv
   variant_calling -> str
   any completed subset of requested families -> reporting/publication

Basecalling is optional when ready BAM/CRAM/uBAM artefacts are imported.
Mapping still owns ingress and compatibility conversion before downstream
families consume aggregate sample state.

The dependency shape applies independently per sample. The project can contain
sample A in ``basecalling``, sample B in ``mapping``, and sample C in
``variant_calling`` at the same time. New bounded entries must preserve that
independence.

Reporting/publication is intentionally not blocked on every requested family.
It declares a ``completed_subset`` prerequisite and can run when at least one
selected upstream family has completed, while recording missing or still-running
families in manifest-backed publication metadata.

Maintenance Rules
-----------------

* Do not introduce a new top-level scheduler family without updating this page,
  ``lib/task_families.nf``, and the shared controller registry.
* Annotation, publication, and partner export are not standalone top-level
  families in this split; they are owned by ``variant_calling`` or
  ``reporting``. Workflow-generated EPI2ME HTML reports and viewer
  configuration files are not supported ``humvar3`` output contracts;
  dashboards, browser views, and API views are Poikilognostikon manifest
  projections.
* SNP, SV, phasing, and haplotagging are modes or products of
  ``variant_calling``. They can have internal task keys, but their scheduler
  state rolls up to the family.
* Every family must use the idempotent task contract in
  ``docs/idempotency.rst``.

Current Entry Status
--------------------

Task 15 introduced ``-entry mapping``. It validates the controller-provided
mapping params, consumes exactly one declared input XAM and reference, emits
``mapped_xam``, ``mapped_xam_index``, ``alignment_metadata``, ``run_ids``,
``mapper_provenance``, and ``qc_stats``, and writes the standard completion
marker only after those declared outputs exist.

Task 16 adds ``-entry sample_aggregation`` as the bounded sample aggregation
entry. It consumes one controller-declared mapped XAM plus its reference assets,
normalises the current aggregate XAM, runs retained ``bamstats``/``flagstat``
and ``mosdepth`` coverage metrics, emits run IDs, basecallers,
``coverage_state``, ``qc_stats``, and ``aggregation_manifest``, then writes the
standard completion marker. Low-coverage data is represented as explicit
``rejected_low_coverage`` sample state in ``coverage_state`` rather than as an
HTML report or an all-run failure. The broader compatibility graph remains in
place until later families move.

Task 17 adds ``-entry variant_calling`` as the bounded small-variant entry for
one controller-declared aggregate XAM, reference, Clair3 model, and
``variant_mode``. The initial bounded mode is SNP calling, with optional GVCF
execution declared as the separate ``variant_mode=snp_gvcf`` contract. It emits
``snp_vcf``, ``snp_vcf_index``, ``variant_calling_manifest``,
``variant_calling_provenance``, and ``qc_stats``; ``snp_gvcf`` and
``snp_gvcf_index`` are required declared outputs only for ``snp_gvcf`` mode.
Phasing, haplotagging, SV refinement, and annotation are recorded as explicit
optional products in the manifest and remain separate bounded modes rather than
hidden ``run_snp`` side effects.

Task 18 extends ``-entry variant_calling`` with the bounded structural-variant
entry for ``variant_mode=sv``. It consumes one controller-declared aggregate
XAM, reference, mosdepth summary, target BED, structured Sniffles options, and
variant/container digests. It emits ``structural_variant_vcf``,
``structural_variant_vcf_index``, ``structural_variant_snf``,
``variant_calling_manifest``, ``variant_calling_provenance``, and
``qc_stats``. Truvari benchmarking is intentionally not part of this bounded
entry; it remains a separate future evaluation task because the compatibility
path still relies on bundled truthset fallbacks.
