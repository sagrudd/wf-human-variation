Bounded Task Families
=====================

``humvar3`` splits the imported workflow into bounded task
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
   * - ``family_germline_snp``
     - family, analysis intent, reference
     - Clair3-Nova trio candidate selection, bounded denovo fragments, and
       per-role merge/sort/DNP annotation from role-keyed per-sample products
       already produced by ``variant_calling`` and ``sample_aggregation``.
   * - ``family_joint_genotyping``
     - family, analysis intent, reference
     - GLnexus joint genotyping from role-keyed family GVCFs with explicit
       pedigree and sample-order validation.
   * - ``family_pedigree_phasing``
     - family, analysis intent, reference
     - WhatsHap pedigree phasing from family joint VCF plus role-keyed
       alignments, with explicit skipped or impossible state.
   * - ``family_haplotagging``
     - family, analysis intent, reference
     - Per-role WhatsHap haplotagging from pedigree-filtered VCF and
       role-keyed alignments, producing manifest-backed haplotagged artefacts.
   * - ``family_sv_calling``
     - family, analysis intent, role, sample, reference
     - Per-member Sniffles2 VCF/SNF generation for incremental family SV
       analysis.
   * - ``family_sv_merging``
     - family, analysis intent, reference
     - Bounded Sniffles2 joint SV merge from controller-declared member SNF
       artefacts.
   * - ``family_mendelian_assessment``
     - family, analysis intent, reference
     - RTG Mendelian assessment over any controller-declared completed family
       SNP/SV variant subset, producing machine-readable summaries only.
   * - ``somatic_tumour_only_snv``
     - analysis intent, tumour role, reference
     - Bounded ClairS-TO tumour-only small-variant calling from role-projected
       sample aggregation artefacts, explicit model/database assets, optional
       BED/candidate/genotyping VCFs, and structured ClairS-TO options.
   * - ``somatic_qc``
     - analysis intent, tumour-normal/control pair, reference
     - Bounded somatic QC projection from tumour and normal/control
       mosdepth-region BEDs plus optional target BED, producing
       ``somatic_shared_regions_bed`` and
       ``somatic_rejected_regions_summary`` for paired callers. Zero shared
       callable bases are emitted as ``shared_region_empty`` for pair-scoped
       coverage blocking.
   * - ``somatic_tumour_only_sv``
     - analysis intent, tumour role, reference
     - Future bounded Severus tumour-only SV calling from role-projected sample
       aggregation artefacts, explicit optional PON/TRF state, genome-build
       validation, and structured Severus options.
   * - ``somatic_paired_snv``
     - analysis intent, tumour-normal/control pair, reference
     - Future bounded ClairS paired calling from explicit ``pair_id``,
       ``role_snapshot_digest``, ``relationship_snapshot_digest``, and shared
       tumour/normal aggregation artefacts plus ready ``normal_vcf_state`` and
       ``shared_region_state``. The paired gate also requires ClairS model
       evidence, a versioned ``clairs_reference_bundle_state``,
       ``clairs_config_digest``, structured ``clairs_options``, and
       ``clairs_options_digest``; these are separate from the tumour-only
       ClairS-TO ``clairs_to_*`` inputs. The first bounded entries are
       ``somatic_paired_snv_candidate`` for ClairS ``extract_pair_candidates``
       and ``somatic_paired_snv_pileup`` for chunk-scoped
       ``create_pair_tensor_pileup`` plus pileup ``predict`` fragments.
       ``somatic_paired_snv_full_alignment`` separately runs
       ``create_pair_tensor`` plus full-alignment ``predict`` fragments from
       controller-selected phased or unphased alignments. The final
       ``somatic_paired_snv_merge`` entry sorts pileup/full-alignment fragments
       and runs ClairS ``merge_vcf`` to produce the deterministic compressed
       VCF/index pair. ``somatic_paired_snv_haplotype_filter`` is the separate
       post-merge haplotype-filter boundary: it consumes the unfiltered VCF,
       pileup/full-alignment VCFs, tumour haplotagged alignment, reference, and
       structured filter options, then records ``completed``,
       ``skipped_disabled``, or ``failed`` state explicitly.
   * - ``somatic_germline_helper``
     - analysis intent, helper role, reference
     - Bounded Clair3 helper execution for tumour, normal, or control role
       aggregation artefacts when paired somatic SNV calling needs reusable
       germline evidence. The ``somatic_germline_helper`` entry records
       computed helper state and emits a ``normal_vcf_state`` projection without
       coupling the helper to the paired ClairS graph.
   * - ``somatic_phasing``
     - analysis intent, sample role, reference
     - Bounded role-scoped WhatsHap phasing from an explicit VCF/index,
       aggregate alignment, selected heterozygous sites, reference assets, and
       structured phasing policy. The entry is independent of paired ClairS
       execution and records skipped/failed/completed phasing state.
   * - ``somatic_haplotagging``
     - analysis intent, sample role, reference
     - Bounded role-scoped WhatsHap haplotagging from a declared phased
       VCF/index and aggregate alignment. Tumour and normal/control
       haplotagging are separate launches, so normal tagging can be omitted by
       policy without changing tumour state.
   * - ``somatic_paired_sv``
     - analysis intent, tumour-normal/control pair, reference
     - Future bounded Severus paired SV calling from explicit pair state,
       shared callable-region state, and controller-declared reference assets.
   * - ``somatic_annotation``
     - analysis intent, source somatic VCF, reference
     - Bounded SnpEff/SnpSift annotation of somatic SNV or SV VCFs from
       controller-declared source artefacts and versioned annotation assets.
   * - ``somatic_methylation_aggregation``
     - analysis intent, sample role, reference
     - Role-scoped modkit aggregation from controller-projected modified-base
       alignments, producing bedMethyl, summary, DSS input, and provenance
       without requiring paired DSS execution.
   * - ``somatic_differential_methylation``
     - analysis intent, tumour-normal/control pair, modification
     - Future bounded paired DSS comparison from role-scoped methylation
       outputs and explicit ``relationship_snapshot_digest``.

Dependency Shape
----------------

The normal dynamic dependency shape is:

.. code-block:: text

   basecalling -> mapping -> sample_aggregation
   sample_aggregation -> variant_calling
   sample_aggregation -> methylation
   sample_aggregation -> cnv
   variant_calling -> str
   variant_calling -> family_germline_snp
   variant_calling -> family_joint_genotyping
   sample_aggregation -> family_pedigree_phasing
   family_joint_genotyping -> family_pedigree_phasing
   sample_aggregation -> family_haplotagging
   family_pedigree_phasing -> family_haplotagging
   sample_aggregation -> family_sv_calling
   family_sv_calling -> family_sv_merging
   family_joint_genotyping or family_sv_merging -> family_mendelian_assessment
   family_germline_snp -> family denovo calling and trio SNP products
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

Family-scoped analysis intent, dynamic sample arrival semantics, retained
family output kinds, report deprecation, and phase-3 method risks are described
in ``docs/family-analysis.rst``.

Maintenance Rules
-----------------

* Do not introduce a new top-level scheduler family without updating this page,
  ``lib/task_families.nf``, and the shared controller registry.
* Singleton variant annotation, publication, and partner export are not
  standalone top-level families in this split; they are owned by
  ``variant_calling`` or ``reporting``. Somatic annotation is the exception
  because it must preserve analysis-intent, role-snapshot, and source-caller
  provenance independently of tumour-only or paired caller execution.
  Workflow-generated EPI2ME HTML reports and viewer configuration files are
  not supported ``humvar3`` output contracts; dashboards, browser views, and
  API views are Poikilognostikon manifest projections.
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

Task 11 adds ``-entry somatic_tumour_only_snv`` as the first bounded somatic
entry. It consumes the tumour role's controller-projected ``aggregate_xam`` and
``aggregate_xam_index``, reference assets, a ClairS-TO model directory, the
explicit non-somatic database bundle, optional target BED/candidate/genotyping
VCFs, structured ``clairs_to_options``, and ``clairs_to_options_digest``. It emits
``somatic_snv_vcf``, ``somatic_snv_vcf_index``,
``somatic_tumour_only_snv_command_json``, ``somatic_tumour_only_snv_logs``,
``somatic_tumour_only_snv_manifest``, ``somatic_provenance``, and
``qc_stats``. It does not infer tumour-only mode from missing ``bam_normal``
and does not launch inherited EPI2ME reports.

Phase 4 task 13 adds ``-entry somatic_tumour_only_sv`` as the bounded Severus
tumour-only SV entry. It consumes the tumour role's controller-projected
``aggregate_xam`` and ``aggregate_xam_index``, reference assets, explicit
optional PON and TRF/VNTR BED paths, and structured ``severus_options``. It
also requires ``severus_options_digest`` and emits ``somatic_sv_vcf``, ``somatic_sv_vcf_index``,
``somatic_sv_raw_directory``, ``somatic_tumour_only_sv_command_json``,
``somatic_tumour_only_sv_manifest``, ``somatic_provenance``, and
``qc_stats``. Optional PON and TRF/VNTR BED files are staged through explicit
Nextflow boundary channels when present. It does not infer tumour-only mode from
missing ``bam_normal`` and does not use inherited hidden ``WFSV_PON_PATH`` or
``WFSV_TRBED_PATH`` assets.

Phase 4 task 14 extends that contract to asset evidence. PON TSV,
TRF/VNTR BED, and segmental-duplication BED states are versioned reference
asset records with asset kind, SHA-256 checksum, genome build, and source
evidence. Hidden inherited defaults such as ``PoN_1000G_hg38.tsv.gz`` under
``WFSV_PON_PATH`` and hardcoded ``hg38.segdups`` / ``SEG_DUP`` annotation are
invalid for bounded somatic SV execution.

Phase 4 task 15 adds ``-entry somatic_annotation`` as the bounded somatic
SnpEff/SnpSift annotation entry. It consumes a controller-declared somatic SNV
or SV VCF plus index, reference id/build, a versioned SnpEff database, optional
ClinVar VCF/index and related SIFT annotation asset state, structured
``somatic_annotation_options``, and explicit config/container digests. It emits
``somatic_annotated_vcf``, ``somatic_annotated_vcf_index``,
``somatic_clinvar_vcf``, ``somatic_clinvar_vcf_index``,
``somatic_annotation_manifest``, ``somatic_annotation_command_json``,
``somatic_provenance``, and ``qc_stats``. Caller entries must not run this as a
side effect, and the bounded entry does not use inherited ``CLINVAR_PATH``,
``getGenome``, ``SEG_DUP``, HTML reports, or hardcoded segmental-duplication
fallbacks.

Phase 4 task 16 adds ``-entry somatic_methylation_aggregation`` as the bounded
role-specific modkit aggregation entry. It consumes one controller-declared
``tumour``, ``normal``, or ``control`` aggregate XAM/index plus reference
FASTA/index, structured ``somatic_methylation_options``,
``modkit_config_digest``, ``somatic_methylation_options_digest``, role
snapshot, and container digest. It emits
``somatic_bedmethyl``, ``somatic_bedmethyl_index``, ``somatic_bigwig``,
``somatic_mod_summary``, ``somatic_dss_input_tsv``,
``somatic_methylation_aggregation_manifest``,
``somatic_methylation_aggregation_command_json``,
``somatic_methylation_aggregation_log``, ``somatic_provenance``, and
``qc_stats``. Tumour-only aggregation can run without normal/control roles and
without DSS; paired DSS comparison remains owned by
``somatic_differential_methylation``.

Phase 4 task 17 makes structured somatic tool option digests part of bounded
task identity. ``clairs_to_options_digest``, ``severus_options_digest``, and
``somatic_methylation_options_digest`` are written to manifests and provenance
input checksum blocks. Free-form inherited ``severus_args``, ``modkit_args``,
ClairS shell fragments, DSS/R fragments, and phasing-tool ``*_args`` are not
accepted by bounded somatic entries.

Phase 4 task 18 keeps low-coverage handling in the controller contract rather
than inside caller command lines. Poikilognostikon projects generic sample
``rejected_low_coverage`` into role-aware somatic states:
``tumour_rejected_low_coverage``, ``normal_rejected_low_coverage``, and paired
``somatic_pair_blocked_low_coverage``. Bounded somatic entries consume only
controller-declared ready roles, so a low-coverage role blocks the affected
intent without being reported as a successful empty analysis.

Other somatic entries remain downstream consumers of the same bounded sample
families. Poikilognostikon projects each ``tumour``, ``normal``, or ``control``
role to existing ``mapping`` and ``sample_aggregation`` outputs, and somatic
tasks consume ``aggregate_xam``, ``aggregate_xam_index``, ``mosdepth_summary``,
and ``coverage_state`` through that projection. They must not add a second
role-specific ingress, mapping, or aggregation graph.

Task 13 adds ``-entry family_germline_snp`` as the bounded trio candidate
selection entry. It consumes role-keyed proband, father, and mother SNP VCFs
and indexes from the phase-2 ``variant_calling`` contract, reference assets,
role and relationship snapshot digests, a Clair3-Nova model digest, and
controller-provided contig policy. It emits ``trio_candidate_beds``,
``trio_candidate_contigs``, ``trio_candidate_command_json``,
``trio_candidate_manifest``, ``family_provenance``, and ``qc_stats``. It does
not call ordinary Clair3, perform denovo calling, or compare sample aliases.
The manifest records the inherited ``wf-trio`` caveat that Clair3-Nova used
pileup VCFs for this stage so the role-keyed input kind can be refined without
changing the bounded entry boundary.

Task 14 adds ``-entry family_germline_snp_denovo`` as the bounded trio
denovo-calling entry for one family/reference/contig snapshot. It consumes the
candidate BED directory from Task 13 plus role-keyed proband, father, and
mother BAMs and indexes, then runs Clair3-Nova ``CallVarBam_Denovo`` only for
non-empty candidate regions on the launched contig. It emits
``trio_denovo_vcf_fragments``, ``trio_denovo_command_json``,
``trio_denovo_state``, ``trio_denovo_manifest``, ``family_provenance``, and
``qc_stats``. Empty candidate regions are represented as explicit task states;
failed candidate-region commands are written to the state file before the task
exits without a completion marker, so restart behaviour remains honest.

Task 15 adds ``-entry family_germline_snp_merge`` as the bounded per-role
trio merge and finalisation entry. It consumes one role/sample's denovo VCF
fragments, the candidate BED directory, singleton SNP VCF/GVCF inputs,
reference assets, and controller-owned digests. The entry runs the retained
Clair3-Nova ``SortVcf_Trio`` and ``MergeVcf_Trio`` transformations, converts
intermediate LZ4 GVCF output, filters ``RefCall`` records from the VCF, moves
``INFO/DNP`` into ``FORMAT/DNP``, compresses, indexes, and emits deterministic
``trio_snp_vcf`` / ``trio_snp_gvcf`` products plus command, manifest,
provenance, and QC JSON. Output filenames are controller-declared task-cache
paths and use stable ``sample_id`` rather than inherited display aliases.

Task 16 adds ``-entry family_joint_genotyping`` as the bounded GLnexus entry.
It consumes role-keyed proband, father, and mother GVCFs and indexes, a
versioned ``glnexus_conf.yml`` file, a pedigree snapshot, reference assets,
role and relationship snapshot digests, and controller-owned input/config
digests. The entry validates distinct role sample IDs, fixed
``proband,father,mother`` sample order, pedigree consistency, and GVCF sample
membership before running GLnexus. It emits ``family_joint_vcf``,
``family_joint_vcf_index``, ``family_joint_genotyping_manifest``,
``family_provenance``, and ``qc_stats``. RTG assessment, pedigree phasing,
haplotagging, reports, and alias branching are deliberately outside this
bounded task.

Task 17 adds ``-entry family_pedigree_phasing`` as the bounded WhatsHap
pedigree-phasing entry. It consumes the Task 16 family joint VCF and index, a
PED-derived relationship snapshot, reference assets, and role-keyed
proband/father/mother aggregate alignments plus indexes. The entry stages
role-named BAMs inside the task work directory, selects pedigree rows by exact
stable sample id, and runs WhatsHap only for the controller-declared contigs.
It emits ``pedigree_filtered_vcf``, ``pedigree_filtered_vcf_index``,
``per_sample_phased_vcf_fragments``, ``pedigree_phasing_manifest``,
``pedigree_phasing_state``, ``family_provenance``, and ``qc_stats``.
Disabled or impossible phasing is represented by explicit task state and
pass-through VCF output rather than silent omission. Haplotagging, RTG
assessment, and reports remain separate bounded tasks.

Task 18 adds ``-entry family_haplotagging`` as the bounded family
haplotagging entry. It consumes the Task 17 pedigree-filtered VCF and index,
role-keyed proband/father/mother aggregate alignments plus indexes, reference
assets, role and relationship snapshot digests, input/config/container
digests, and explicit controller-declared contigs. The entry filters the
phased VCF by stable sample id and contig, runs WhatsHap haplotagging, merges
the declared contig projections per role, and emits
``family_haplotagged_alignments``, ``family_haplotagged_contig_manifest``,
``family_haplotagging_manifest``, ``family_haplotagging_state``,
``family_provenance``, and ``qc_stats``. These outputs are normal manifest
artefacts for downstream STR, SV, methylation, and publication projections;
they are not hidden SNP intermediates.

Task 19 adds ``-entry family_sv_calling`` as the bounded per-member family SV
entry. It consumes one declared role/sample's aggregate alignment plus index,
mosdepth summary, target BED, reference assets, role and relationship snapshot
digests, structured Sniffles options, and controller-owned digests. The entry
retains the phase-2 Sniffles2 call, null-support cleanup, coverage/target
filter, sort, and index path, but emits family-scoped metadata:
``structural_variant_vcf``, ``structural_variant_vcf_index``,
``structural_variant_snf``, ``family_sv_calling_command_json``,
``family_sv_calling_manifest``, ``family_provenance``, and ``qc_stats``.
Each role/sample can complete independently, and ``structural_variant_snf`` is
the first-class input to later joint family SV merging.

Task 20 adds ``-entry family_sv_merging`` as the bounded joint family SV entry.
It consumes controller-declared member SNFs from Task 19, reference assets,
target BED, role and relationship snapshot digests, structured Sniffles merge
options, and input/config/container digests. The entry validates each selected
member SNF against the requested reference digest and optional genome-build
setting, runs Sniffles joint merge without inherited implicit ``--phase``, then
filters, sorts, compresses, and indexes the family SV VCF. It emits
``family_sv_vcf``, ``family_sv_vcf_index``,
``family_sv_merging_command_json``, ``family_sv_merging_manifest``,
``family_sv_merging_state``, ``family_provenance``, and ``qc_stats``.
Subset merges are explicit through structured options and recorded in task
state.

Task 21 adds ``-entry family_mendelian_assessment`` as the bounded RTG
Mendelian assessment entry. It consumes a PED-derived pedigree snapshot, an RTG
SDF reference, role and relationship snapshot digests, RTG config/container
digests, and either the family joint SNP VCF, the family SV VCF, or both. The
entry converts the pedigree snapshot into a task-local PED file, runs
``rtg mendelian`` separately for each selected variant class, and emits
``family_rtg_snp_summary``, ``family_rtg_sv_summary``,
``mendelian_summary``, ``mendelian_metrics``,
``family_mendelian_assessment_manifest``,
``family_mendelian_assessment_state``, ``family_provenance``, and
``qc_stats``. SNP-only or SV-only assessment is explicit subset mode. No HTML,
report MIME metadata, or inherited report framework output is produced.

Task 22 consolidates the family-analysis documentation contract. The canonical
Sphinx surface is ``docs/family-analysis.rst`` for family analysis intent,
dynamic arrival semantics, family prerequisites, retained family outputs, and
method compatibility risks. ``docs/outputs.rst`` lists retained joint VCF/GVCF,
SNF, haplotagged alignment, PED snapshot, and Mendelian summary output kinds.
The old ``wf-trio`` report outputs remain explicitly deprecated and must not be
reintroduced as bounded task products.

Phase 2 Task 18 extends ``-entry variant_calling`` with the bounded structural-variant
entry for ``variant_mode=sv``. It consumes one controller-declared aggregate
XAM, reference, mosdepth summary, target BED, structured Sniffles options, and
variant/container digests. It emits ``structural_variant_vcf``,
``structural_variant_vcf_index``, ``structural_variant_snf``,
``variant_calling_manifest``, ``variant_calling_provenance``, and
``qc_stats``. Truvari benchmarking is intentionally not part of this bounded
entry; it remains a separate future evaluation task because the compatibility
path still relies on bundled truthset fallbacks.

Phase 2 Task 19 adds ``-entry cnv`` as the bounded CNV entry. Spectre and QDNAseq are
separate ``cnv_mode`` values. Spectre requires an explicit ``snp_vcf``
prerequisite plus mosdepth coverage artefacts, so selecting CNV no longer
silently activates SNP. QDNAseq requires ``aggregate_xam_kind=bam``; CRAM input
must be converted by a visible upstream mapping or adapter task. Both modes
emit ``cnv_vcf``, ``cnv_vcf_index``, ``cnv_manifest``, ``cnv_provenance``, and
``qc_stats``. Spectre additionally emits ``cnv_bed`` and ``cnv_karyotype``;
QDNAseq additionally emits ``cnv_segments_bed`` and ``cnv_segments_vcf``.

Phase 2 Task 20 adds ``-entry str`` as the bounded STR entry. It consumes a
controller-declared haplotagged-contig manifest, reference assets, repeat BED,
variant catalogue, sex state, STR config digest, and container digest for one
sample/reference. It emits ``str_vcf``, ``str_vcf_index``, ``str_loci_tsv``,
``straglr_tsv``, ``stranger_tsv``, ``str_content_csv``, ``str_manifest``,
``str_provenance``, and ``qc_stats``. Missing haplotagged products are handled
as explicit ``variant_calling`` prerequisites; selecting STR does not silently
activate SNP, haplotagging, STR publication, or HTML report generation.

Task 21 adds ``-entry methylation`` as the bounded modified-base entry.
``methylation_mode=unphased`` consumes the aggregate XAM and produces
bedMethyl/bigWig plus manifest/provenance/QC. ``methylation_mode=phased``
requires controller-declared haplotagged XAM and records haplotype-specific
products as optional phased artefacts. Missing haplotagged input is handled by
the controller prerequisite policy, either blocking or degrading to unphased;
the bounded entry does not silently activate SNP, phasing, or haplotagging.
