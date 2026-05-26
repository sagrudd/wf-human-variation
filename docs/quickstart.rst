Quickstart
==========

Local Requirements
------------------

The workflow requires:

* Nextflow;
* Docker or Singularity/Apptainer;
* a human reference FASTA;
* a BAM, CRAM, or uBAM input;
* enough local or cluster resources for the requested analysis families.

Recommended resources for whole-genome analysis are approximately 32 CPUs and
128 GB RAM. Smaller resources may work for narrower analyses but should be
treated as a test-specific configuration rather than a production default.

Minimal Command
---------------

Run a basic small-variant and structural-variant analysis:

.. code-block:: bash

   nextflow run . \
     --bam /path/to/sample.bam \
     --ref /path/to/reference.fa \
     --sample_name SAMPLE \
     --snp \
     --sv \
     -profile standard

Common Feature Flags
--------------------

Use one or more of these top-level analysis flags:

.. list-table::
   :header-rows: 1

   * - Flag
     - Effect
   * - ``--snp``
     - Enable small variant calling.
   * - ``--sv``
     - Enable structural variant calling.
   * - ``--cnv``
     - Enable CNV calling with Spectre by default.
   * - ``--cnv --use_qdnaseq``
     - Enable CNV calling with QDNAseq.
   * - ``--str``
     - Enable STR genotyping. This also requires haplotagging support.
   * - ``--mod``
     - Enable modified-base aggregation.
   * - ``--phased``
     - Request phased outputs where supported.

Maintenance Note
----------------

This quickstart is not a substitute for the schema. When adding or changing a
parameter, update ``nextflow.config``, ``nextflow_schema.json``, and
``docs/parameters.rst`` together.
