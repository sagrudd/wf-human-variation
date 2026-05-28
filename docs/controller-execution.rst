Controller-Led Execution
========================

``humvar3`` must not evolve by making ``main.nf`` a larger monolithic DAG.
The imported graph remains useful as a source of known tool invocations,
process wiring, and output expectations, but those contracts should be moved
behind controller-launched bounded entries as each family is migrated.

The target operating model is:

1. The Python controller observes runtime events and projects manifest state.
2. The controller decides whether a bounded task family should launch, skip, or
   refresh.
3. Nextflow executes the selected bounded unit.
4. The bounded unit writes declared outputs and a completion marker.
5. The bounded unit or controller writes task provenance into the shared
   manifest.
6. The controller records task and output events, then plans any newly
   unblocked downstream family.

Nextflow is therefore an execution backend for bounded work. It should not be
responsible for discovering unrelated new samples, waiting for all samples, or
deciding global analysis state.

Per-Sample Progress
-------------------

The controller must allow different samples to occupy different task-family
states at the same time. For example, sample A may have an active
``basecalling`` task, sample B may have an active ``mapping`` task, and sample C
may already be running ``variant_calling``. This is normal runtime state, not a
partial failure.

Bounded entries should consume only their launched sample, reference, artefact,
and task key. They must not derive readiness from a project-wide phase such as
"all samples basecalled" or "all samples mapped".

Launch Contract
---------------

The shared controller command is:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry mapping \
     --outdir /analysis/project-001 \
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
     --output qc_stats=metadata/mapping-qc.json

This writes a bounded params file containing:

* ``task_family``;
* ``task_key``;
* ``task_dir`` / ``task_cache_dir``;
* ``completion_marker_path``;
* declared ``output_paths``.

The command skips execution when the completion marker is valid for the same
task key unless the controller requests ``--force-refresh``.

Current Bounded Entries
-----------------------

Task 15 promotes the first bounded entry into a real mapping execution unit:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry mapping \
     --outdir /analysis/project-001 \
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
     --output qc_stats=metadata/mapping-qc.json

This launches ``nextflow run ../wf-human-variation -entry mapping`` without
executing the default compatibility graph. The params JSON must provide
``sample_id``, ``input_xam``, ``input_kind`` (``bam``, ``cram``, ``ubam``, or
``basecalled_bam``), ``input_digest``, ``reference_fasta``, ``reference_id``,
``mapper``, ``mapper_options``, ``mapper_options_digest``,
``container_digest``, and ``output_format``. The entry validates those
controller-provided values, checks whether the input already matches the
reference, remaps when required with the retained
``samtools reset -> fastq -> minimap2 -> reheader -> sort/index`` command
shape, writes the declared mapping outputs, and only then writes the standard
``.gnostikon_task_complete.json`` marker.

Task 16 adds the bounded sample aggregation entry:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry sample_aggregation \
     --outdir /analysis/project-001 \
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
     --output aggregation_manifest=metadata/aggregation-manifest.json

The params JSON must provide ``sample_id``, ``mapped_xam``,
``mapped_xam_index``, ``mapped_xam_digest``, ``reference_fasta``,
``reference_index``, ``reference_id``, ``aggregation_config_digest``,
``coverage_config_digest``, ``container_digest``, ``output_format``, and
``aggregation_options``. The entry runs only aggregation/QC-owned work:
aggregate XAM normalisation, ``bamstats``/``flagstat`` metrics, run-id and
basecaller extraction, ``mosdepth`` coverage metrics, explicit
``coverage_state``, and the aggregation manifest. It does not launch alignment
HTML generation, downstream analysis families, or report publication.

Somatic work must reuse this path. The controller projects role-scoped
``shared_role_artefacts`` from the existing ``mapping`` and
``sample_aggregation`` provenance, including ``mapped_xam`` lineage,
``aggregate_xam``, ``aggregate_xam_index``, ``mosdepth_summary``, and
``coverage_state``. Bounded somatic entries must consume those artefacts and
must not expose ``bam_tumor``/``bam_normal`` or a private remapping path as
controller-facing runtime inputs.

Somatic low-coverage decisions are controller-owned. The shared manifest maps
sample-level ``rejected_low_coverage`` into ``tumour_rejected_low_coverage``,
``normal_rejected_low_coverage``, or paired
``somatic_pair_blocked_low_coverage`` before bounded somatic entries are
scheduled. Unaffected tumour-only intents can continue when only a non-required
normal/control role is rejected.

Paired somatic scheduling is also controller-owned. ``pair_readiness_state``
must be ``ready`` before ``somatic_paired_snv``, ``somatic_paired_sv``,
``somatic_germline_helper``, or ``somatic_differential_methylation`` entries are
planned. The readiness gate checks the current ``pair_id``, tumour and
normal/control role assignments, role mapping outputs, role aggregation outputs,
coverage input state, method-specific reference compatibility, and
``relationship_snapshot_digest``. Paired SNV also requires ready
``normal_vcf_state`` with VCF/index checksums, reference evidence, and caller
provenance when known; an imported VCF with missing index or incompatible
reference blocks as ``invalid_normal_vcf``. Paired SNV and paired SV also
require ready ``shared_region_state`` from bounded somatic QC; missing shared
regions remain visible as ``waiting_for_shared_regions`` and invalid shared BED
or rejected-summary evidence blocks as ``invalid_shared_regions``. Paired SNV
additionally requires paired ClairS-specific evidence: ``clairs_model`` or
``clairs_model_state``, ``clairs_model_table_digest``, ready
``clairs_reference_bundle_state``, ``clairs_config_digest``, structured
``clairs_options``, and ``clairs_options_digest``. Missing ClairS-specific
inputs remain ``waiting_for_clairs_prerequisites`` and invalid options or
bundle metadata block as ``invalid_paired_snv_inputs``. A valid
zero-overlap result from bounded somatic QC is ``shared_region_empty`` and is a
terminal pair coverage state, not a missing-input condition. Missing
state remains visible as scheduler reasons such as ``waiting_for_normal``,
``waiting_for_normal_vcf``, or ``waiting_for_reference_compatibility``; bounded
entries must not infer readiness from whole-run channel completion.

The bounded ``somatic_germline_helper`` entry is the maintained workflow
surface for computed helper VCFs. Controllers may instead project
``normal_vcf_state`` from imported evidence or mark helper calling as skipped
when policy or input availability says it is unnecessary. Those states remain
manifest-owned as ``imported``, ``computed``, or ``skipped`` rather than being
encoded as hidden ``normal_vcf`` parameters inside the paired SNV entry.

Task 31 adds ``-entry somatic_germline_helper`` as the bounded Clair3 helper
unit for paired SNV support. It consumes a controller-declared tumour, normal,
or control aggregate alignment plus reference and Clair3 model assets, emits
``germline_helper_vcf``, ``germline_helper_vcf_index``,
``germline_helper_command_json``, ``germline_helper_manifest``,
``germline_helper_logs``, ``somatic_provenance``, and ``qc_stats``, and records
the computed helper VCF as reusable ``normal_vcf_state`` evidence.

Task 32 adds ``-entry somatic_phasing`` and ``-entry somatic_haplotagging`` as
separate bounded role-scoped units. ``somatic_phasing`` selects heterozygous
sites from a controller-declared VCF/index, phases the selected sites against
the role aggregate alignment, and emits ``selected_heterozygous_sites``,
``somatic_phased_vcf``, command, manifest, state, provenance, and QC artefacts.
``somatic_haplotagging`` consumes the phased VCF/index and the same role
alignment to emit ``somatic_haplotagged_xam``, index, contig manifest, command,
manifest, state, provenance, and QC artefacts. Both entries record explicit
policy state, so normal/control haplotagging can be skipped while tumour
haplotagging remains available for haplotype filtering.

Task 27 adds ``-entry somatic_paired_snv_candidate`` as the bounded paired
ClairS candidate-extraction unit. It consumes controller-projected tumour and
normal/control aggregate alignments, normal VCF/index evidence, shared callable
regions, reference assets, ClairS model/reference-bundle assets, optional target
BED and genotyping VCF inputs, and structured ``clairs_options``. It emits
``somatic_candidate_snv``, ``somatic_candidate_indel``,
``somatic_candidate_hybrid``, ``somatic_candidate_bed``,
``somatic_paired_snv_candidate_command_json``,
``somatic_paired_snv_candidate_manifest``, ``somatic_provenance``, and
``qc_stats`` with a completion marker.

Task 28 adds ``-entry somatic_paired_snv_pileup`` as the chunk-scoped paired
ClairS pileup tensor/prediction unit. It consumes a single candidate BED or
region file, candidate variant artefact, paired alignments, reference assets,
ClairS model evidence, ``region_id``, ``contig``, ``variant_type``, and the
same structured ``clairs_options`` digest. It emits
``somatic_pileup_prediction_fragments``,
``somatic_pileup_prediction_command_json``,
``somatic_pileup_prediction_manifest``, ``somatic_provenance``, and
``qc_stats``. The task key must include the region/chunk identity so failed or
completed pileup chunks can be retried without replaying candidate extraction
or unrelated regions.

Task 29 adds ``-entry somatic_paired_snv_full_alignment`` as the matching
chunk-scoped paired ClairS full-alignment tensor/prediction unit. It consumes a
controller-selected tumour and normal/control alignment pair, which may be
phased or unphased as recorded by ``alignment_state``, plus candidate BED and
candidate variant artefacts, reference assets, ClairS model evidence,
``region_id``, ``contig``, ``variant_type``, and structured
``clairs_options``. It emits ``somatic_full_alignment_prediction_fragments``,
``somatic_full_alignment_prediction_command_json``,
``somatic_full_alignment_prediction_manifest``, ``somatic_provenance``, and
``qc_stats``. Final sorting, haplotype filtering, and merge with pileup
fragments remain separate downstream tasks.

Task 30 adds ``-entry somatic_paired_snv_merge`` as the deterministic final
paired SNV/indel merge unit. It consumes manifested pileup and full-alignment
fragment directories, a controller-declared contig-order file, reference assets,
``variant_type``, and structured ``clairs_options``. It runs ClairS
``sort_vcf`` over each fragment family, runs ClairS ``merge_vcf`` with the
configured quality threshold, normalises compression/indexing when required,
and emits ``somatic_snv_vcf``, ``somatic_snv_vcf_index``,
``somatic_paired_snv_command_json``, ``somatic_paired_snv_manifest``,
``somatic_provenance``, and ``qc_stats``. A zero-variant VCF remains a
manifested output state rather than being relabelled as an execution failure.

Phase 4 task 25 projects ``paired_coverage_state`` as ``pair_ready``,
``tumour_failed``, ``normal_failed``, ``both_failed``, or
``shared_region_empty``. Those states block only the affected pair and do not
change readiness for unrelated samples or unrelated somatic intents.

Phase 4 task 24 adds bounded somatic QC:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry somatic_qc \
     --outdir /analysis/project-001 \
     --task-family somatic_qc \
     --analysis-intent-id ait_somatic_001 \
     --tumour-sample-id smp_tumour \
     --normal-or-control-sample-id smp_normal

The controller supplies tumour and normal/control ``mosdepth_regions`` artefacts
and optional target BED state. The entry emits shared callable regions,
rejected-region summary, metrics, provenance, and a completion marker only.

Task 17 adds the bounded small-variant entry:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry variant_calling \
     --outdir /analysis/project-001 \
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
     --output qc_stats=qc/variant-calling-qc.json

The params JSON must provide ``sample_id``, ``aggregate_xam``,
``aggregate_xam_index``, ``aggregate_xam_digest``, ``reference_fasta``,
``reference_index``, ``reference_id``, ``clair3_model``,
``clair3_model_digest``, ``variant_mode``, ``variant_config_digest``,
``container_digest``, and structured ``variant_options``. The entry runs only
small-variant-owned work for the launched sample/reference/mode. Optional GVCF
is selected by ``variant_mode=snp_gvcf`` plus
``variant_options.emit_gvcf=true`` and requires declared ``snp_gvcf`` and
``snp_gvcf_index`` output paths. Phasing, haplotagging, SV refinement, and
annotation are explicit optional products in the manifest and are not activated
as side effects.

Phase 4 task 11 adds bounded ClairS-TO tumour-only SNV calling:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry somatic_tumour_only_snv \
     --outdir /analysis/project-001 \
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
     --key-field clairs_to_options_digest=sha256:clairs-to-options \
     --key-field container_digest=sha256:container \
     --params-json somatic-tumour-only-snv.params.json \
     --output somatic_snv_vcf=variants/somatic/smp_tumour.wf-somatic-snv.vcf.gz \
     --output somatic_snv_vcf_index=variants/somatic/smp_tumour.wf-somatic-snv.vcf.gz.tbi \
     --output somatic_tumour_only_snv_manifest=metadata/somatic-tumour-only-snv-manifest.json \
     --output somatic_tumour_only_snv_command_json=metadata/somatic-tumour-only-snv-command.json \
     --output somatic_tumour_only_snv_logs=logs/somatic-tumour-only-snv.log \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-tumour-only-snv-qc.json

The params JSON must provide ``analysis_intent_id``, ``sample_id``,
``role_snapshot_digest``, the tumour ``aggregate_xam`` and
``aggregate_xam_index`` projected from ``sample_aggregation``, reference
assets and digests, ``clairs_to_model``, ``clairs_to_database_bundle``,
``clairs_to_config_digest``, ``clairs_to_options_digest``,
``container_digest``, and structured ``clairs_to_options``. Optional
``target_bed``, ``candidate_vcf``, and
``genotyping_vcf`` inputs are explicit contract fields. ``candidate_vcf`` uses
ClairS-TO hybrid mode and ``genotyping_vcf`` uses genotyping mode; the bounded
entry rejects both being present at once. The final retained data filename is
``<sample_id>.wf-somatic-snv.vcf.gz`` plus ``.tbi``.

Phase 4 task 13 adds bounded Severus tumour-only SV calling:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry somatic_tumour_only_sv \
     --outdir /analysis/project-001 \
     --task-family somatic_tumour_only_sv \
     --key-field analysis_intent_id=som_001 \
     --key-field sample_id=smp_tumour \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field aggregate_xam_index_digest=sha256:aggregate-index \
     --key-field severus_config_digest=sha256:config \
     --key-field severus_options_digest=sha256:severus-options \
     --key-field container_digest=sha256:container \
     --params-json somatic-tumour-only-sv.params.json \
     --output somatic_sv_vcf=variants/somatic/smp_tumour.wf-somatic-sv.vcf.gz \
     --output somatic_sv_vcf_index=variants/somatic/smp_tumour.wf-somatic-sv.vcf.gz.tbi \
     --output somatic_sv_raw_directory=variants/somatic/severus-output \
     --output somatic_tumour_only_sv_manifest=metadata/somatic-tumour-only-sv-manifest.json \
     --output somatic_tumour_only_sv_command_json=metadata/somatic-tumour-only-sv-command.json \
     --output somatic_provenance=metadata/somatic-provenance.json \
     --output qc_stats=qc/somatic-tumour-only-sv-qc.json

The params JSON must provide ``analysis_intent_id``, ``sample_id``,
``role_snapshot_digest``, tumour ``aggregate_xam`` and
``aggregate_xam_index`` projected from ``sample_aggregation``, reference
assets and digests, ``severus_config_digest``, ``severus_options_digest``,
``container_digest``, and structured ``severus_options``. Optional
``pon_file`` and ``trf_bed`` inputs
are explicit contract fields with digests when provided and are staged through
optional Nextflow boundary channels rather than hidden container defaults. The
retained data filename is ``<sample_id>.wf-somatic-sv.vcf.gz`` plus ``.tbi``.

Phase 4 task 15 adds bounded somatic SNV/SV annotation:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry somatic_annotation \
     --outdir /analysis/project-001 \
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
     --output qc_stats=qc/somatic-annotation-qc.json

The params JSON must provide ``analysis_intent_id``,
``role_snapshot_digest``, ``source_output_artefact_id``, ``annotation_mode``
(``snv`` or ``sv``), ``reference_id``, ``reference_genome_build``,
``source_vcf``/``source_vcf_index`` plus digests, a versioned
``snpeff_database`` directory and database name, ``snpeff_database_digest``,
``annotation_config_digest``, ``container_digest``, and structured
``somatic_annotation_options``. Optional ``clinvar_vcf``,
``clinvar_vcf_index``, and related ``sift_annotation`` assets are explicit
fields. Caller entries supply source VCFs; they must not invoke annotation as a
side effect.

Phase 4 task 16 adds bounded somatic modified-base aggregation:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry somatic_methylation_aggregation \
     --outdir /analysis/project-001 \
     --task-family somatic_methylation_aggregation \
     --key-field analysis_intent_id=som_001 \
     --key-field sample_id=smp_tumour \
     --key-field sample_role=tumour \
     --key-field reference_id=GRCh38 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field role_aggregate_xam_digest=sha256:aggregate \
     --key-field role_aggregate_xam_index_digest=sha256:aggregate-index \
     --key-field modkit_config_digest=sha256:modkit-config \
     --key-field somatic_methylation_options_digest=sha256:modkit-options \
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
     --output qc_stats=qc/somatic-methylation-aggregation-qc.json

The params JSON must provide ``analysis_intent_id``, ``sample_id``,
``sample_role`` (``tumour``, ``normal``, or ``control``),
``role_snapshot_digest``, reference id/build, role aggregate XAM/index plus
digests, reference FASTA/index, ``modkit_config_digest``, ``container_digest``,
``somatic_methylation_options_digest``, and structured
``somatic_methylation_options``. This entry runs role-specific modkit
aggregation only; it does not run DSS, infer tumour-only mode from a missing
normal, or publish MOD HTML reports.

Task 13 adds bounded trio candidate selection:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_germline_snp \
     --outdir /analysis/project-001 \
     --task-family family_germline_snp \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field clair3_nova_model_digest=sha256:model \
     --key-field family_germline_config_digest=sha256:config \
     --params-json family-germline-snp.params.json \
     --output trio_candidate_manifest=metadata/trio-candidate-manifest.json \
     --output trio_candidate_beds=outputs/trio-candidate-beds \
     --output trio_candidate_contigs=metadata/trio-candidate-contigs.txt \
     --output trio_candidate_command_json=metadata/select-candidates-command.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/family-germline-qc.json

The params JSON must provide role-keyed proband, father, and mother SNP VCFs
and indexes, reference assets, ``family_id``, ``analysis_intent_id``, role and
relationship snapshot digests, ``clair3_nova_model``,
``clair3_nova_model_digest``, ``family_germline_config_digest``,
``container_digest``, and ``family_germline_options.candidate_contigs``. This
entry wraps only Clair3-Nova ``SelectCandidates_Trio`` and leaves denovo
calling to the next bounded entry.

Task 14 adds bounded trio denovo calling:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_germline_snp_denovo \
     --outdir /analysis/project-001 \
     --task-family family_germline_snp \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field contig=chr1 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field trio_candidate_beds_digest=sha256:candidates \
     --key-field clair3_nova_model_digest=sha256:model \
     --key-field family_germline_config_digest=sha256:config \
     --params-json family-germline-snp-denovo.params.json \
     --output trio_denovo_manifest=metadata/trio-denovo-manifest.json \
     --output trio_denovo_vcf_fragments=outputs/trio-denovo-fragments \
     --output trio_denovo_state=metadata/trio-denovo-state.json \
     --output trio_denovo_command_json=metadata/trio-denovo-command.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/family-germline-denovo-qc.json

The params JSON must provide the Task 13 candidate BED directory, one launched
``contig``, role-keyed proband/father/mother BAMs and indexes, reference
assets, role and relationship digests, Clair3-Nova model/config/container
digests, and structured ``family_germline_denovo_options``. Empty candidate
regions produce a completed no-op state; failed candidate-region commands are
recorded in ``trio_denovo_state`` before the task exits without a completion
marker.

Task 15 adds bounded trio merge/sort/DNP finalisation:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_germline_snp_merge \
     --outdir /analysis/project-001 \
     --task-family family_germline_snp \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field role=proband \
     --key-field sample_id=smp_child \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field trio_denovo_vcf_fragments_digest=sha256:denovo \
     --key-field trio_candidate_beds_digest=sha256:candidates \
     --key-field snp_vcf_digest=sha256:pileup \
     --key-field snp_gvcf_digest=sha256:gvcf \
     --key-field clair3_nova_model_digest=sha256:model \
     --key-field family_germline_config_digest=sha256:config \
     --params-json family-germline-snp-merge.params.json \
     --output trio_snp_vcf=variants/trio-snp.vcf.gz \
     --output trio_snp_vcf_index=variants/trio-snp.vcf.gz.tbi \
     --output trio_snp_gvcf=variants/trio-snp.gvcf.gz \
     --output trio_snp_gvcf_index=variants/trio-snp.gvcf.gz.tbi \
     --output trio_merge_manifest=metadata/trio-merge-manifest.json \
     --output trio_merge_command_json=metadata/trio-merge-command.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/family-germline-merge-qc.json

The params JSON must provide one role/sample, the denovo fragment directory,
candidate BED directory, singleton SNP VCF/GVCF inputs and indexes, reference
assets, role and relationship digests, Clair3-Nova model/config/container
digests, and structured ``family_germline_merge_options.contigs``. This entry
is intentionally per role, so child, father, and mother products can be
refreshed independently without project-wide grouping.

Task 16 adds bounded GLnexus joint genotyping:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_joint_genotyping \
     --outdir /analysis/project-001 \
     --task-family family_joint_genotyping \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field pedigree_snapshot_digest=sha256:pedigree \
     --key-field proband_snp_gvcf_digest=sha256:child-gvcf \
     --key-field father_snp_gvcf_digest=sha256:father-gvcf \
     --key-field mother_snp_gvcf_digest=sha256:mother-gvcf \
     --key-field glnexus_config_digest=sha256:glnexus-config \
     --key-field reference_digest=sha256:reference \
     --params-json family-joint-genotyping.params.json \
     --output family_joint_vcf=variants/family-joint.vcf.gz \
     --output family_joint_vcf_index=variants/family-joint.vcf.gz.tbi \
     --output family_joint_genotyping_manifest=metadata/family-joint-genotyping.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/family-joint-genotyping-qc.json

The params JSON must provide role-keyed proband/father/mother GVCFs and
indexes, stable sample IDs for each role, a pedigree snapshot, reference
assets, ``glnexus_config``, role and relationship digests, input/config
digests, and structured ``family_joint_genotyping_options``. The bounded task
validates role sample order and GVCF sample membership before launch, then runs
only GLnexus joint genotyping and index creation. RTG Mendelian assessment and
pedigree phasing are separate downstream entries.

Task 17 adds bounded WhatsHap pedigree phasing:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_pedigree_phasing \
     --outdir /analysis/project-001 \
     --task-family family_pedigree_phasing \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field pedigree_snapshot_digest=sha256:pedigree \
     --key-field family_joint_vcf_digest=sha256:family-joint-vcf \
     --key-field proband_bam_digest=sha256:child-bam \
     --key-field father_bam_digest=sha256:father-bam \
     --key-field mother_bam_digest=sha256:mother-bam \
     --key-field whatshap_config_digest=sha256:whatshap-config \
     --key-field reference_digest=sha256:reference \
     --params-json family-pedigree-phasing.params.json \
     --output pedigree_filtered_vcf=variants/pedigree-filtered.vcf.gz \
     --output pedigree_filtered_vcf_index=variants/pedigree-filtered.vcf.gz.tbi \
     --output per_sample_phased_vcf_fragments=variants/phased-fragments \
     --output pedigree_phasing_manifest=metadata/pedigree-phasing.json \
     --output pedigree_phasing_state=metadata/pedigree-phasing-state.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/pedigree-phasing-qc.json

The params JSON must provide stable proband/father/mother sample IDs, the
family joint VCF and index, a PED-derived pedigree snapshot, role-keyed
aggregate BAMs plus indexes, reference assets, role and relationship digests,
input/config/container digests, and structured
``family_pedigree_phasing_options.contigs``. The bounded task runs only
WhatsHap pedigree phasing and per-sample phased-fragment extraction. Disabled
or impossible phasing is recorded as explicit state and pass-through VCF
output; haplotagging and reporting are separate entries.

Task 18 adds bounded family haplotagging:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_haplotagging \
     --outdir /analysis/project-001 \
     --task-family family_haplotagging \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field pedigree_filtered_vcf_digest=sha256:pedigree-filtered-vcf \
     --key-field proband_xam_digest=sha256:child-bam \
     --key-field father_xam_digest=sha256:father-bam \
     --key-field mother_xam_digest=sha256:mother-bam \
     --key-field whatshap_config_digest=sha256:whatshap-config \
     --key-field reference_digest=sha256:reference \
     --params-json family-haplotagging.params.json \
     --output family_haplotagged_alignments=alignments/family-haplotagged \
     --output family_haplotagged_contig_manifest=metadata/family-haplotagged-contigs.json \
     --output family_haplotagging_manifest=metadata/family-haplotagging.json \
     --output family_haplotagging_state=metadata/family-haplotagging-state.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/family-haplotagging-qc.json

The params JSON must provide stable proband/father/mother sample IDs,
``pedigree_filtered_vcf`` plus index, role-keyed aggregate XAMs plus indexes,
reference assets, role and relationship digests, input/config/container
digests, and structured ``family_haplotagging_options.contigs``. The bounded
task runs only WhatsHap haplotagging and per-role alignment projection for the
controller-declared contigs. Downstream STR, SV, methylation, and publication
work consumes the emitted manifest artefacts; this entry does not run
haplotagphase, SNP calling, or reports.

Task 19 adds bounded per-member family SV calling:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_sv_calling \
     --outdir /analysis/project-001 \
     --task-family family_sv_calling \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field role=proband \
     --key-field sample_id=smp_child \
     --key-field reference_id=ref_001 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field mosdepth_summary_digest=sha256:mosdepth \
     --key-field target_bed_digest=sha256:target-bed \
     --key-field sniffles_config_digest=sha256:sniffles-config \
     --key-field reference_digest=sha256:reference \
     --params-json family-sv-calling.params.json \
     --output structural_variant_vcf=variants/proband.sv.vcf.gz \
     --output structural_variant_vcf_index=variants/proband.sv.vcf.gz.tbi \
     --output structural_variant_snf=variants/proband.snf \
     --output family_sv_calling_command_json=metadata/proband-sv-command.json \
     --output family_sv_calling_manifest=metadata/proband-sv.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/proband-sv-qc.json

The params JSON must provide one stable ``role``/``sample_id`` pair,
``aggregate_xam`` plus index, ``mosdepth_summary``, ``target_bed``, reference
assets, role and relationship digests, input/config/container digests, and
structured ``structural_variant_options``. The bounded task runs Sniffles2,
retains the phase-2 coverage/target filter, writes VCF/index and SNF output,
and records role-aware command, manifest, provenance, and QC JSON. It does not
perform joint SV merging, SV phasing, RTG assessment, reports, or trio-wide
grouping.

Task 20 adds bounded joint family SV merging:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_sv_merging \
     --outdir /analysis/project-001 \
     --task-family family_sv_merging \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field proband_snf_digest=sha256:child-snf \
     --key-field father_snf_digest=sha256:father-snf \
     --key-field mother_snf_digest=sha256:mother-snf \
     --key-field target_bed_digest=sha256:target-bed \
     --key-field sniffles_config_digest=sha256:sniffles-config \
     --key-field reference_digest=sha256:reference \
     --params-json family-sv-merging.params.json \
     --output family_sv_vcf=variants/family.sv.vcf.gz \
     --output family_sv_vcf_index=variants/family.sv.vcf.gz.tbi \
     --output family_sv_merging_command_json=metadata/family-sv-merge-command.json \
     --output family_sv_merging_manifest=metadata/family-sv-merge.json \
     --output family_sv_merging_state=metadata/family-sv-merge-state.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/family-sv-merge-qc.json

The params JSON must provide the selected role SNFs, role sample IDs, per-role
SNF digests and reference digests, reference assets, target BED, role and
relationship digests, config/container digests, and structured
``family_sv_merging_options``. The bounded task validates member SNF reference
compatibility, records subset state when requested, runs Sniffles joint merge,
and emits the family SV VCF/index plus command, manifest, state, provenance,
and QC JSON. It does not run per-member SV calling, SV phasing, RTG assessment,
reports, or Nextflow-side ``groupTuple`` aggregation.

Task 21 adds bounded RTG Mendelian assessment:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry family_mendelian_assessment \
     --outdir /analysis/project-001 \
     --task-family family_mendelian_assessment \
     --key-field family_id=fam_001 \
     --key-field analysis_intent_id=ait_001 \
     --key-field reference_id=ref_001 \
     --key-field role_snapshot_digest=sha256:roles \
     --key-field relationship_snapshot_digest=sha256:relationships \
     --key-field pedigree_snapshot_digest=sha256:pedigree \
     --key-field family_joint_vcf_digest=sha256:joint-vcf \
     --key-field family_sv_vcf_digest=sha256:family-sv \
     --key-field rtg_config_digest=sha256:rtg-config \
     --key-field reference_digest=sha256:reference \
     --params-json family-mendelian-assessment.params.json \
     --output family_rtg_snp_summary=qc/family-snp-rtg.txt \
     --output family_rtg_sv_summary=qc/family-sv-rtg.txt \
     --output mendelian_summary=metadata/mendelian-summary.json \
     --output mendelian_metrics=metadata/mendelian-metrics.json \
     --output family_mendelian_assessment_manifest=metadata/mendelian-assessment.json \
     --output family_mendelian_assessment_state=metadata/mendelian-assessment-state.json \
     --output family_provenance=metadata/family-provenance.json \
     --output qc_stats=qc/mendelian-assessment-qc.json

The params JSON must provide ``pedigree_snapshot``, ``reference_sdf``, the
selected family VCF inputs and indexes, role and relationship digests, RTG
config/container digests, and structured
``family_mendelian_assessment_options``. The bounded task runs
``rtg mendelian`` for each selected variant class and emits text summaries,
JSON summary/metrics, manifest, state, provenance, and QC artefacts. It does
not generate HTML or use the inherited report framework.

Phase 2 Task 18 adds the bounded structural-variant entry as ``variant_mode=sv``:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry variant_calling \
     --outdir /analysis/project-001 \
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
     --output qc_stats=qc/variant-calling-qc.json

The params JSON must provide ``sample_id``, ``aggregate_xam``,
``aggregate_xam_index``, ``aggregate_xam_digest``, ``reference_fasta``,
``reference_index``, ``reference_id``, ``mosdepth_summary``, ``target_bed``,
``variant_mode=sv``, ``variant_config_digest``, ``container_digest``, and
structured ``structural_variant_options``. The entry runs Sniffles2, removes
unsupported null-support records, applies the retained coverage/target
filtering command, sorts and indexes the VCF, writes SNF output, and records
benchmarking as deferred manifest state rather than launching Truvari.

Phase 2 Task 19 adds the bounded CNV entry with explicit Spectre and QDNAseq modes:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry cnv \
     --outdir /analysis/project-001 \
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
     --output qc_stats=qc/cnv-qc.json

The Spectre params JSON must provide ``sample_id``, aggregate XAM fields,
reference fields, ``snp_vcf``, ``snp_vcf_index``, ``snp_vcf_digest``,
mosdepth summary/regions/distribution/threshold artefacts, ``cnv_mode``,
``cnv_config_digest``, ``container_digest``, and structured ``cnv_options``.
The QDNAseq mode uses the same entry with ``cnv_mode=qdnaseq`` and declared
``cnv_segments_bed``/``cnv_segments_vcf`` outputs. QDNAseq requires
``aggregate_xam_kind=bam`` and uses the structured option
``cnv_options.qdnaseq_options.bin_size`` so CRAM-to-BAM conversion remains a
visible prerequisite.

Phase 2 Task 20 adds the bounded STR entry:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry str \
     --outdir /analysis/project-001 \
     --task-family str \
     --key-field sample_id=smp_001 \
     --key-field reference_id=ref_001 \
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
     --output qc_stats=qc/str-qc.json

The params JSON must provide ``sample_id``, ``reference_id``,
``haplotagged_contig_manifest``, ``haplotagged_contig_digest``,
``reference_fasta``, ``reference_index``, ``sex``, ``repeat_bed``,
``variant_catalogue``, ``str_config_digest``, ``container_digest``, and
structured ``str_options``. The haplotagged-contig manifest must list per-contig
BAMs using ``contig``/``xam`` or ``sq``/``bam`` fields. Missing haplotagged
products are a controller prerequisite state, not a reason for STR to launch
SNP or haplotagging implicitly. The bounded entry emits only machine-readable
STR products plus manifest/provenance/QC JSON; HTML STR reports are outside the
``humvar3`` contract.

Task 21 adds the bounded methylation entry with explicit unphased and phased
modes:

.. code-block:: text

   gnostikon-workflow-control nextflow-task \
     --workflow ../wf-human-variation \
     --entry methylation \
     --outdir /analysis/project-001 \
     --task-family methylation \
     --key-field sample_id=smp_001 \
     --key-field reference_id=ref_001 \
     --key-field methylation_mode=unphased \
     --key-field aggregate_xam_digest=sha256:aggregate \
     --key-field methylation_config_digest=sha256:methylation \
     --key-field container_digest=sha256:container \
     --params-json methylation.params.json \
     --output bedmethyl=methylation/methylation.bedmethyl.gz \
     --output bigwig=methylation/methylation.5mC.bw \
     --output methylation_manifest=metadata/methylation-manifest.json \
     --output methylation_provenance=metadata/methylation-provenance.json \
     --output qc_stats=qc/methylation-qc.json

The params JSON must provide ``sample_id``, ``reference_id``,
``methylation_mode``, aggregate XAM fields, reference fields,
``methylation_config_digest``, ``container_digest``, and structured
``methylation_options``. ``methylation_mode=phased`` additionally requires
``haplotagged_xam``, ``haplotagged_xam_index``, and
``haplotagged_xam_digest``. If phased output is requested but haplotagged input
is not ready, the controller may degrade to ``methylation_mode=unphased`` and
record the reason ``phased_methylation_uses_haplotagged_bam_when_available``.
The entry itself never launches SNP, phasing, haplotagging, report publication,
or combined metrics JSON.

Workflow Maintenance Rules
--------------------------

* New Nextflow work should be reachable through a bounded ``-entry`` that maps
  to one of the eight families in ``docs/bounded-task-families.rst``.
* Bounded entries must consume controller-provided params rather than rebuilding
  launch-time global state from arbitrary project directories.
* Bounded entries must write only their declared task-cache outputs and
  completion marker. User-facing publication belongs to ``reporting``.
* Broad ``collect()``, unkeyed ``combine()``, all-sample joins, and global
  mutable ``params.wf`` state must not be introduced into bounded entries.
  Follow ``docs/keyed-joins.rst``.
* ``optionalBoundaryChannel()`` is permitted only where the controller has
  declared an explicit subset boundary. In phase-3 family work this currently
  means optional role SNFs for ``family_sv_merging`` and optional SNP/SV VCF
  subsets for ``family_mendelian_assessment``. It must not be used as a new
  spelling of the old ``OPTIONAL_FILE`` sentinel.
* Remaining broad joins inventoried by Task 22 are compatibility-only debt in
  the anonymous workflow and legacy subworkflows. Bounded readiness must be
  based on controller state and declared task inputs, not channel completion.
* Runtime state that used to be pushed into ``params.wf[...]`` must be written
  through ``gnostikon-workflow-control`` manifest/event commands. Ingressed run
  IDs use ``record-ingress-runids`` in bounded/controller-led paths and remain
  visible as per-sample ``*.runids.txt`` artefacts in the compatibility graph.
* Bounded entries must emit a provenance JSON document and submit it through
  ``record-task-provenance``. The manifest record must include tool versions,
  container image and digest, command arguments, input checksums, task status,
  completion marker path, and output artefacts.
* ``main.nf`` remains a compatibility path and reference implementation until
  the bounded entries replace the imported launch-time workflow behavior. Do
  not add new dynamic runtime semantics there.
