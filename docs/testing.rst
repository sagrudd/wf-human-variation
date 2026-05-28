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

Synthetic Fixtures
------------------

Phase 2 task 23 adds tiny local fixtures under
``tests/fixtures/synthetic`` so contract tests do not need downloaded genomic
datasets. The committed text fixtures cover a synthetic reference, named BED
targets, VCF headers, mosdepth pass/fail summaries, and sample-sheet ordering
or duplicate cases.

Binary XAM files are not committed. ``make_xam_fixtures.py`` generates tiny
mapped/unmapped BAM and mapped CRAM files when ``pysam`` is installed; tests
skip only that XAM-specific check if the active Python lacks ``pysam``. True
restart/skip execution remains controller-owned in
``gnostikon-workflow-control`` and Poikilognostikon. Workflow-local tests assert
the bounded completion-marker contract and the absence of public HTML report
outputs.

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

The Phase 4 task 11 bounded ClairS-TO tumour-only SNV entry can be dry-run
without genomic data:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry somatic_tumour_only_snv \
     --outdir /tmp/humvar-bounded \
     --task-family somatic_tumour_only_snv \
     --key-field analysis_intent_id=som_001 \
     --key-field sample_id=smp_tumour \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field aggregate_xam_index_digest=sha256:aggregate-index \
     --key-field clairs_to_model_digest=sha256:model \
     --key-field clairs_to_model_table_digest=sha256:model-table \
     --key-field clairs_to_database_bundle_digest=sha256:database \
     --key-field clairs_to_config_digest=sha256:config \
     --key-field container_digest=sha256:container \
     --params-json somatic-tumour-only-snv.params.json \
     --output somatic_snv_vcf=variants/somatic/smp_tumour.wf-somatic-snv.vcf.gz \
     --output somatic_snv_vcf_index=variants/somatic/smp_tumour.wf-somatic-snv.vcf.gz.tbi \
     --output somatic_tumour_only_snv_manifest=metadata/somatic-tumour-only-snv-manifest.json \
     --output somatic_tumour_only_snv_command_json=metadata/somatic-tumour-only-snv-command.json \
     --output somatic_tumour_only_snv_logs=logs/somatic-tumour-only-snv.log \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-tumour-only-snv-qc.json \
     --dry-run

Where Nextflow and the owned ClairS-TO runtime are available, run the generated
params with
``nextflow run . -entry somatic_tumour_only_snv -params-file <params-file>``.
This executes only the bounded tumour-only caller for one tumour
role/reference/analysis intent and records optional BED, hybrid candidate VCF,
and genotyping VCF state in manifest and provenance.

The Phase 4 task 13 bounded Severus tumour-only SV entry can be dry-run without
genomic data:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry somatic_tumour_only_sv \
     --outdir /tmp/humvar-bounded \
     --task-family somatic_tumour_only_sv \
     --key-field analysis_intent_id=som_001 \
     --key-field sample_id=smp_tumour \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field aggregate_xam_index_digest=sha256:aggregate-index \
     --key-field severus_config_digest=sha256:config \
     --key-field container_digest=sha256:container \
     --params-json somatic-tumour-only-sv.params.json \
     --output somatic_sv_vcf=variants/somatic/smp_tumour.wf-somatic-sv.vcf.gz \
     --output somatic_sv_vcf_index=variants/somatic/smp_tumour.wf-somatic-sv.vcf.gz.tbi \
     --output somatic_sv_raw_directory=variants/somatic/severus-output \
     --output somatic_tumour_only_sv_manifest=metadata/somatic-tumour-only-sv-manifest.json \
     --output somatic_tumour_only_sv_command_json=metadata/somatic-tumour-only-sv-command.json \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-tumour-only-sv-qc.json \
     --dry-run

Where Nextflow and the owned Severus runtime are available, run the generated
params with
``nextflow run . -entry somatic_tumour_only_sv -params-file <params-file>``.
This executes only bounded tumour-only SV calling for one tumour
role/reference/analysis intent and records optional PON and TRF/VNTR BED state
in manifest and provenance.

The Phase 4 task 34 bounded Severus paired SV entry can be dry-run without
genomic data:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry somatic_paired_sv \
     --outdir /tmp/humvar-bounded \
     --task-family somatic_paired_sv \
     --key-field analysis_intent_id=som_001 \
     --key-field pair_id=pair_001 \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationship \
     --key-field tumour_aggregate_xam_digest=sha256:tumour-aggregate \
     --key-field tumour_aggregate_xam_index_digest=sha256:tumour-index \
     --key-field normal_or_control_aggregate_xam_digest=sha256:normal-aggregate \
     --key-field normal_or_control_aggregate_xam_index_digest=sha256:normal-index \
     --key-field severus_config_digest=sha256:config \
     --key-field severus_options_digest=sha256:severus-options \
     --key-field container_digest=sha256:container \
     --params-json somatic-paired-sv.params.json \
     --output somatic_sv_vcf=variants/somatic/pair_001.wf-somatic-sv.vcf.gz \
     --output somatic_sv_vcf_index=variants/somatic/pair_001.wf-somatic-sv.vcf.gz.tbi \
     --output somatic_sv_raw_directory=variants/somatic/pair_001.severus-output \
     --output somatic_paired_sv_manifest=metadata/somatic-paired-sv-manifest.json \
     --output somatic_paired_sv_command_json=metadata/somatic-paired-sv-command.json \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-paired-sv-qc.json \
     --dry-run

Where Nextflow and the owned Severus runtime are available, run the generated
params with
``nextflow run . -entry somatic_paired_sv -params-file <params-file>``.
This executes only bounded paired SV calling for one tumour-normal/control pair
and records required TRF/VNTR BED state, optional PON state, structured
Severus options, and pair identity in manifest and provenance.

Poikilognostikon Phase 4 task 19 adds local tumour-only synthetic contract
tests around these bounded entries. The tests do not download large datasets:
they build a tiny SQLite event store and assert that
``somatic_tumour_only_snv`` and ``somatic_tumour_only_sv`` can be scheduled
from ready manifest state, duplicate aggregate artefacts do not create duplicate
scheduled tasks, completion markers are reused on restart, missing PON remains
the explicit ``optional_not_provided`` fallback, and
``tumour_rejected_low_coverage`` blocks the tumour-only callers honestly. These
tests live in Poikilognostikon because the controller owns scheduling; this
workflow must preserve the bounded entry contracts and deterministic output
names consumed by those tests.

The Phase 4 task 15 bounded somatic annotation entry can be dry-run without
genomic data:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry somatic_annotation \
     --outdir /tmp/humvar-bounded \
     --task-family somatic_annotation \
     --key-field analysis_intent_id=som_001 \
     --key-field source_output_artefact_id=out_somatic_snv \
     --key-field annotation_mode=snv \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field source_vcf_digest=sha256:source-vcf \
     --key-field source_vcf_index_digest=sha256:source-index \
     --key-field snpeff_database_digest=sha256:snpeff-db \
     --key-field annotation_config_digest=sha256:annotation-config \
     --key-field container_digest=sha256:container \
     --params-json somatic-annotation.params.json \
     --output somatic_annotated_vcf=variants/somatic/annotated.vcf.gz \
     --output somatic_annotated_vcf_index=variants/somatic/annotated.vcf.gz.tbi \
     --output somatic_clinvar_vcf=variants/somatic/clinvar.vcf.gz \
     --output somatic_clinvar_vcf_index=variants/somatic/clinvar.vcf.gz.tbi \
     --output somatic_annotation_manifest=metadata/somatic-annotation-manifest.json \
     --output somatic_annotation_command_json=metadata/somatic-annotation-command.json \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-annotation-qc.json \
     --dry-run

Where Nextflow and the owned SnpEff/SnpSift runtime are available, run the
generated params with
``nextflow run . -entry somatic_annotation -params-file <params-file>``. This
executes only bounded annotation for one source VCF and records ClinVar/SIFT
asset state in manifest and provenance.

The Phase 4 task 16 bounded somatic methylation aggregation entry can be
dry-run without genomic data:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry somatic_methylation_aggregation \
     --outdir /tmp/humvar-bounded \
     --task-family somatic_methylation_aggregation \
     --key-field analysis_intent_id=som_001 \
     --key-field sample_id=smp_tumour \
     --key-field sample_role=tumour \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field role_aggregate_xam_digest=sha256:aggregate \
     --key-field role_aggregate_xam_index_digest=sha256:aggregate-index \
     --key-field modkit_config_digest=sha256:modkit-config \
     --key-field container_digest=sha256:container \
     --params-json somatic-methylation-aggregation.params.json \
     --output somatic_bedmethyl=methylation/somatic.tumour.bedmethyl.gz \
     --output somatic_bedmethyl_index=methylation/somatic.tumour.bedmethyl.gz.tbi \
     --output somatic_bigwig=methylation/somatic.tumour.5mC.bw \
     --output somatic_mod_summary=qc/somatic.tumour.mod-summary.tsv \
     --output somatic_dss_input_tsv=methylation/somatic.tumour.dss.tsv \
     --output somatic_methylation_aggregation_manifest=metadata/somatic-methylation-aggregation-manifest.json \
     --output somatic_methylation_aggregation_command_json=metadata/somatic-methylation-aggregation-command.json \
     --output somatic_methylation_aggregation_log=logs/somatic-methylation-aggregation.log \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-methylation-aggregation-qc.json \
     --dry-run

Where Nextflow and the owned modkit runtime are available, run the generated
params with
``nextflow run . -entry somatic_methylation_aggregation -params-file <params-file>``.
This executes only role-specific modified-base aggregation; DSS and paired
comparison remain separate.

The Phase 4 task 35 bounded paired DSS entry can be dry-run without genomic
data:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry somatic_differential_methylation \
     --outdir /tmp/humvar-bounded \
     --task-family somatic_differential_methylation \
     --key-field analysis_intent_id=som_001 \
     --key-field pair_id=pair_001 \
     --key-field tumour_sample_id=smp_tumour \
     --key-field normal_or_control_sample_id=smp_normal \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationship \
     --key-field modification_code=5mC \
     --key-field tumour_dss_input_tsv_digest=sha256:tumour-dss \
     --key-field normal_or_control_dss_input_tsv_digest=sha256:normal-dss \
     --key-field dss_config_digest=sha256:dss-config \
     --key-field dss_options_digest=sha256:dss-options \
     --key-field r_bioconductor_lock_digest=sha256:r-lock \
     --key-field container_digest=sha256:container \
     --params-json somatic-differential-methylation.params.json \
     --output somatic_dml_tsv=methylation/pair_001.5mC.dml.tsv \
     --output somatic_dmr_tsv=methylation/pair_001.5mC.dmr.tsv \
     --output somatic_differential_methylation_manifest=metadata/somatic-differential-methylation-manifest.json \
     --output somatic_differential_methylation_command_json=metadata/somatic-differential-methylation-command.json \
     --output somatic_differential_methylation_log=logs/somatic-dss.log \
     --output somatic_r_versions=metadata/somatic-r-versions.tsv \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-differential-methylation-qc.json \
     --dry-run

Where Nextflow and the owned DSS/R runtime are available, run the generated
params with
``nextflow run . -entry somatic_differential_methylation -params-file <params-file>``.
This executes only paired DSS comparison for one modification code and records
DSS options, R package versions, input digests, and pair identity in manifest
and provenance.

Phase 4 task 37 adds Poikilognostikon-side dynamic pair arrival tests for the
bounded somatic contracts. Those tests build a tiny SQLite event store and
prove deterministic scheduling when tumour arrives before normal, when
normal arrives before tumour, an imported normal VCF exists without a normal
BAM, pair membership is superseded, duplicate role artefacts are present, and a
failed paired SNV task is retried until a succeeding task attempt records
completion.
The workflow must preserve the output names, entry contracts, and manifest
fields consumed by those tests; it must not replace them with report HTML,
presentation paths, or directory scanning.

Phase 4 task 38 adds Poikilognostikon-side paired synthetic integration tests
using tiny BAM/VCF/BED fixtures. Those tests compute fixture checksums, project
paired tumour/normal readiness, derive shared callable-region state from
somatic QC outputs, dry-run bounded ``somatic_paired_snv``, verify
completion-marker reuse, and replay successful paired SNV provenance into
``paired_output_contracts``. The workflow contract must continue to expose the
bounded entry parameters and output kinds consumed by those tests without
requiring large external datasets.

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

The Task 19 bounded CNV entry can be dry-run in Spectre mode:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry cnv \
     --outdir /tmp/humvar-bounded \
     --task-family cnv \
     --key-field sample_id=smp_001 \
     --key-field reference_id=ref_001 \
     --key-field cnv_mode=spectre \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field snp_vcf_digest=sha256:snp \
     --key-field cnv_config_digest=sha256:cnv \
     --key-field container_digest=sha256:container \
     --params-json cnv-spectre.params.json \
     --output cnv_vcf=cnv/cnv.vcf.gz \
     --output cnv_vcf_index=cnv/cnv.vcf.gz.tbi \
     --output cnv_bed=cnv/cnv.bed \
     --output cnv_karyotype=cnv/predicted-karyotype.txt \
     --output cnv_manifest=metadata/cnv-manifest.json \
     --output cnv_provenance=metadata/cnv-provenance.json \
     --output qc_stats=qc/cnv-qc.json \
     --dry-run

QDNAseq dry-runs use ``cnv_mode=qdnaseq`` and declare ``cnv_segments_bed`` and
``cnv_segments_vcf`` instead of Spectre ``cnv_bed`` and ``cnv_karyotype``.
The params must also declare ``aggregate_xam_kind=bam`` and may set
``cnv_options.qdnaseq_options.bin_size``.

The Task 20 bounded STR entry can be dry-run with a params file that declares
the reference assets, repeat BED, variant catalogue, sex state, and
haplotagged-contig manifest:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry str \
     --outdir /tmp/humvar-bounded \
     --task-family str \
     --key-field sample_id=smp_001 \
     --key-field reference_id=GRCh38 \
     --key-field haplotagged_contig_digest=sha256:haplotagged \
     --key-field str_config_digest=sha256:str-config \
     --key-field container_digest=sha256:container \
     --params-json str.params.json \
     --output str_vcf=str/str.vcf.gz \
     --output str_vcf_index=str/str.vcf.gz.tbi \
     --output str_loci_tsv=str/str-loci.tsv \
     --output straglr_tsv=str/straglr.tsv \
     --output stranger_tsv=str/stranger.tsv \
     --output str_content_csv=str/str-content-all.csv \
     --output str_manifest=metadata/str-manifest.json \
     --output str_provenance=metadata/str-provenance.json \
     --output qc_stats=qc/str-qc.json \
     --dry-run

Where Nextflow, Straglr, Stranger, and the workflow glue scripts are available,
run the generated params with
``nextflow run . -entry str -params-file <params-file>``. This executes only
bounded STR calling for one sample/reference and leaves missing haplotagged
products as controller prerequisite state rather than implicitly launching SNP.

The Task 21 bounded methylation entry can be dry-run in unphased mode:

.. code-block:: bash

   gnostikon-workflow-control nextflow-task \
     --workflow . \
     --entry methylation \
     --outdir /tmp/humvar-bounded \
     --task-family methylation \
     --key-field sample_id=smp_001 \
     --key-field reference_id=GRCh38 \
     --key-field methylation_mode=unphased \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field methylation_config_digest=sha256:methylation \
     --key-field container_digest=sha256:container \
     --params-json methylation.params.json \
     --output bedmethyl=methylation/methylation.bedmethyl.gz \
     --output bigwig=methylation/methylation.5mC.bw \
     --output methylation_manifest=metadata/methylation-manifest.json \
     --output methylation_provenance=metadata/methylation-provenance.json \
     --output qc_stats=qc/methylation-qc.json \
     --dry-run

Phased dry-runs use ``methylation_mode=phased`` and the params JSON must also
declare ``haplotagged_xam``, ``haplotagged_xam_index``, and
``haplotagged_xam_digest``. If those artefacts are not ready, the controller
should either block the phased request or degrade to unphased mode with the
prerequisite reason recorded in manifest state.

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
