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
     - Per-sample aggregate BAM refresh from ready mapped chunks.
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
     - sample or project, report family
     - QC reports, workflow reports, IGV packaging, partner export, and
       publication.

Dependency Shape
----------------

The normal dynamic dependency shape is:

.. code-block:: text

   basecalling -> mapping -> sample_aggregation
   sample_aggregation -> variant_calling
   sample_aggregation -> methylation
   sample_aggregation -> cnv
   variant_calling -> str
   requested families -> reporting

Basecalling is optional when ready BAM/CRAM/uBAM artefacts are imported.
Mapping still owns ingress and compatibility conversion before downstream
families consume aggregate sample state.

Maintenance Rules
-----------------

* Do not introduce a new top-level scheduler family without updating this page,
  ``lib/task_families.nf``, and the shared controller registry.
* Annotation, publication, partner export, and IGV packaging are not standalone
  top-level families in this split; they are owned by ``variant_calling`` or
  ``reporting``.
* SNP, SV, phasing, and haplotagging are modes or products of
  ``variant_calling``. They can have internal task keys, but their scheduler
  state rolls up to the family.
* Every family must use the idempotent task contract in
  ``docs/idempotency.rst``.
