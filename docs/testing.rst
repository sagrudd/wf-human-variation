Testing
========

Testing Goals
-------------

Tests should protect:

* parameter validation;
* ingress behavior;
* reference preparation;
* reference/genome-build compatibility validation for annotation, CNV, and STR;
* branch activation and hidden couplings;
* output filenames and optionality;
* machine-readable publication/export outputs;
* failure behavior for invalid inputs and low coverage, including per-sample
  ``rejected_low_coverage`` state that does not block unrelated samples at the
  maintained rejection boundary.

Local Smoke Test
----------------

When suitable data is available, run a minimal smoke test:

.. code-block:: bash

   nextflow run . \
     --bam /path/to/demo.bam \
     --ref /path/to/demo.fasta \
     --sample_id DEMO-STABLE-ID \
     --sample_name DEMO \
     --snp \
     -profile standard

The Task 15 bounded mapping entry can be dry-run through the controller without
genomic data by using a params file that declares the mapping-specific inputs:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry mapping \
     --outdir /tmp/humvar-bounded \
     --task-family mapping \
     --key-field sample_id=smp_001 \
     --key-field reference_id=ref_001 \
     --key-field input_digest=sha256:abc \
     --key-field mapper=minimap2 \
     --key-field mapper_options_digest=sha256:def \
     --key-field container_digest=sha256:container \
     --params-json mapping.params.json \
     --output mapped_xam=outputs/reads.sorted.bam \
     --output mapped_xam_index=outputs/reads.sorted.bam.bai \
     --output alignment_metadata=metadata/alignment.json \
     --output run_ids=metadata/runids.txt \
     --output mapper_provenance=metadata/mapper-provenance.json \
     --output qc_stats=metadata/mapping-qc.json \
     --dry-run

Where Nextflow is available, the generated ``nextflow.params.json`` can then
be run with ``nextflow run . -entry mapping -params-file <params-file>``. This
validates the mapping contract, executes only the bounded mapping unit, writes
the declared outputs, and creates the completion marker used by controller
skip/reuse checks.

The Task 16 bounded sample aggregation entry can be dry-run the same way:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry sample_aggregation \
     --outdir /tmp/humvar-bounded \
     --task-family sample_aggregation \
     --key-field sample_id=smp_001 \
     --key-field reference_id=ref_001 \
     --key-field mapped_xam_digest=sha256:mapped \
     --key-field aggregation_config_digest=sha256:aggregation \
     --key-field coverage_config_digest=sha256:coverage \
     --key-field container_digest=sha256:container \
     --params-json sample-aggregation.params.json \
     --output aggregate_xam=outputs/aggregate.bam \
     --output aggregate_xam_index=outputs/aggregate.bam.bai \
     --output readstats=qc/readstats.tsv.gz \
     --output flagstat=qc/flagstat.tsv \
     --output run_ids=qc/runids.txt \
     --output basecallers=qc/basecallers.txt \
     --output mosdepth_summary=qc/mosdepth.summary.txt \
     --output mosdepth_regions=qc/mosdepth.regions.bed.gz \
     --output mosdepth_distribution=qc/mosdepth.global.dist.txt \
     --output mosdepth_thresholds=qc/mosdepth.thresholds.bed.gz \
     --output coverage_state=qc/coverage-state.json \
     --output qc_stats=qc/sample-aggregation-qc.json \
     --output aggregation_manifest=metadata/aggregation-manifest.json \
     --dry-run

Where Nextflow is available, run the generated params with
``nextflow run . -entry sample_aggregation -params-file <params-file>``. This
executes only the bounded sample aggregation entry and emits machine-readable
QC including ``coverage_state``.

The Task 17 bounded small-variant entry can be dry-run without genomic data:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry variant_calling \
     --outdir /tmp/humvar-bounded \
     --task-family variant_calling \
     --key-field sample_id=smp_001 \
     --key-field reference_id=ref_001 \
     --key-field variant_mode=snp \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field clair3_model_digest=sha256:model \
     --key-field variant_config_digest=sha256:variant \
     --key-field container_digest=sha256:container \
     --params-json variant-calling.params.json \
     --output snp_vcf=variants/snp.vcf.gz \
     --output snp_vcf_index=variants/snp.vcf.gz.tbi \
     --output variant_calling_manifest=metadata/variant-calling-manifest.json \
     --output variant_calling_provenance=metadata/variant-calling-provenance.json \
     --output qc_stats=qc/variant-calling-qc.json \
     --dry-run

Where Nextflow and Clair3 are available, run the generated params with
``nextflow run . -entry variant_calling -params-file <params-file>``. This
executes only bounded SNP calling for one sample/reference/mode and records
deferred phasing, haplotagging, SV refinement, and annotation as explicit
manifest state.

The Task 18 bounded structural-variant entry can be dry-run through the same
entry point:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry variant_calling \
     --outdir /tmp/humvar-bounded \
     --task-family variant_calling \
     --key-field sample_id=smp_001 \
     --key-field reference_id=ref_001 \
     --key-field variant_mode=sv \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field variant_config_digest=sha256:sv-config \
     --key-field container_digest=sha256:container \
     --params-json structural-variant.params.json \
     --output structural_variant_vcf=variants/sv.vcf.gz \
     --output structural_variant_vcf_index=variants/sv.vcf.gz.tbi \
     --output structural_variant_snf=variants/sv.snf \
     --output variant_calling_manifest=metadata/variant-calling-manifest.json \
     --output variant_calling_provenance=metadata/variant-calling-provenance.json \
     --output qc_stats=qc/variant-calling-qc.json \
     --dry-run

Where Nextflow and Sniffles2 are available, run the generated params with
``nextflow run . -entry variant_calling -params-file <params-file>``. This
executes only bounded SV calling for one sample/reference/mode and records
deferred benchmark, phasing, and annotation products as explicit manifest
state.

Broader smoke tests should cover combinations such as:

* two ingressed sample folders with ``--sample_id alias_a=smp_a,alias_b=smp_b``;
* ``--snp --sv``;
* ``--cnv`` with Spectre;
* ``--cnv --use_qdnaseq``;
* ``--str``;
* ``--mod``;
* ``--phased``;
* low-coverage rejection paths;
* incompatible reference builds, especially STR with non-hg38 reference state;
* CRAM and uBAM ingress.

Documentation Build Test
------------------------

Documentation changes must build with Sphinx:

.. code-block:: bash

   python -m sphinx -W -b html docs docs/_build/html

Read the Docs is configured to treat warnings as failures.

Maintenance Expectations
------------------------

Do not treat ignored processes or unavailable large datasets as proof that a
change is safe. If a full workflow test cannot be run, document what was run
and what remains unverified.
