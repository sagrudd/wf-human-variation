Somatic Import Baseline
=======================

Phase 4 starts from the reviewed ``wf-somatic-variation`` source state, but
somatic code is not part of the maintained ``wf-human-variation`` runtime until
later tasks define bounded entries, controller contracts, tests, and owned
runtime images.

Reviewed Source
---------------

The import evidence is recorded in the Poikilognostikon repository as
``phase-4-somatic-baseline.md``.

The reviewed upstream source state is:

.. list-table::
   :header-rows: 1

   * - Field
     - Value
   * - Upstream repository
     - ``https://github.com/epi2me-labs/wf-somatic-variation``
   * - Reviewed commit
     - ``d6471f430757a2bc73f7defd248a546f80b4ddf6``
   * - Manifest version
     - ``v1.5.1``
   * - Reviewed describe output
     - ``v1.5.1-1-gd6471f4``
   * - Pinned inherited ``wf-human-variation`` submodule
     - ``42ffefba3fe4010818634478ec8851f1a03ee477``

Import Boundary
---------------

The inherited workflow is evidence for method contracts and output
expectations. It is not an implementation pattern to recreate.

Do not import:

* EPI2ME HTML reports or report-only Python;
* IGV/Desktop presentation hooks;
* telemetry or ping behaviour;
* ``OPTIONAL_FILE`` sentinels into controller-facing contracts;
* ONT sha-like container tags as release runtime dependencies;
* static tumour/normal CLI mode selection from missing ``bam_normal``;
* broad unkeyed joins or global collection barriers.

The detailed presentation-removal contract is maintained in
``phase-4-somatic-presentation-removal.md``. That contract explicitly excludes
the inherited read-QC, SNV, SV, MOD, and joint-hub HTML reports,
``workflow-glue report*`` commands, ``report_utils`` Python, ``configure_igv``,
``igv.json`` publication, ``Pinguscript`` telemetry, ``disable_ping``, and
``epi2mecloud`` metadata.

Future somatic entries must be controller-launched bounded tasks with explicit
analysis intent, role or pair state, deterministic task keys, completion
markers, structured options, provenance, and owned container evidence.
Runtime role state is supplied by Poikilognostikon ``sample_role.assigned``
events for ``tumour``, ``normal``, and ``control``; ``wf-human-variation`` must
not infer those roles from filenames, static parameters, or missing normal
inputs.
Paired tumour-normal/control identity is supplied by
``somatic_pair.registered`` events with durable ``pair_id``,
``pairing_timestamp_utc``, and ``relationship_snapshot_digest`` fields. A
tumour-first pair may be projected as ``waiting_for_normal`` until the normal
member arrives; bounded workflow entries must not recover pair state from
filenames or aliases.

The controller projects ``pair_readiness_state`` separately from ``pair_state``.
Paired bounded entries may be planned only when tumour and normal/control role
assignments, role mapping outputs, role aggregation outputs, coverage input
state, method-specific reference compatibility, and the current
``relationship_snapshot_digest`` are ready. Waiting and blocked reasons such as
``waiting_for_normal``, ``waiting_for_reference_compatibility``,
``somatic_pair_blocked_low_coverage``, and ``incompatible_reference`` remain
controller state; workflow entries consume declared files only after scheduling.

The Poikilognostikon-side analysis intent contract is maintained in
``poikilognostikon-somatic-analysis-intents.md``. This workflow documentation
records the import boundary only; it does not add somatic runtime entry points.

Method Compatibility
--------------------

Somatic method, model, reference, container, and ARM64 release risks are tracked
in the Poikilognostikon compatibility register
``wf-human-variation-method-compatibilities.md``. The Phase 4 task 5 section
covers ClairS, ClairS-TO, Severus, DSS/R/Bioconductor, somatic model tables,
PoN and TRF assets, segmental-duplication assets, tandem-repeat assets,
phasing, annotation, workflow-local helpers, and the local GB10 somatic
training image.

Inherited ONT containers and container-local databases are source evidence
only. Future somatic runtime entries must use owned images, immutable digests,
explicit asset checksums, runtime version probes, and concordance tests before
ARM64 support is claimed.

The owned replacement-image design is maintained in
``phase-4-somatic-container-plan.md``. It keeps common HTS/QC, ClairS,
ClairS-TO, optional Clair3 helper calling, phasing, Severus, modkit,
DSS/R/Bioconductor, annotation, and retained helper code in distinct image
families so each capability can be validated, updated, or removed without
dragging the rest of the somatic architecture with it.

Manifest Boundary
-----------------

Poikilognostikon owns somatic manifest state. The maintained projection is the
top-level ``somatic`` map keyed by ``analysis_intent_id``; it records
``role_snapshot_digest``, ``tumour_only_state``, ``pon_state``,
``pair_id``, ``pair_state``, ``pair_readiness_state``,
``relationship_snapshot_digest``,
``normal_vcf_state``, ``somatic_caller_state``, ``germline_helper_state``,
``methylation_state``, ``variant_annotation_state``, ``task_attempt_ids``,
``output_artefact_ids``, and ``outputs_by_kind``.

``normal_vcf_state`` is the only supported representation of a precomputed
normal/control VCF. A ready state requires the VCF path and SHA-256, VCF index
path and SHA-256, compatible sample/reference/genome-build evidence, and
caller/source provenance when known. ``somatic_paired_snv`` entries must wait
for this state or for ``somatic_germline_helper`` to produce it; they must not
accept a hidden ``normal_vcf`` parameter that bypasses manifest validation.
The helper state is explicit: imported VCF evidence is ``imported``, bounded
Clair3 helper execution is ``computed``, and policy decisions not to call a
helper are ``skipped``.

Paired ClairS readiness is distinct from tumour-only ClairS-TO readiness.
``somatic_paired_snv`` requires ready tumour and normal/control role artefacts,
ready normal VCF state, ready shared callable regions, ``pair_ready`` coverage,
``clairs`` reference compatibility, ClairS model evidence, a versioned
``clairs_reference_bundle_state``, ``clairs_config_digest``, structured
``clairs_options``, and ``clairs_options_digest``. These fields use the
``clairs_*`` namespace and must not be satisfied by the tumour-only
``clairs_to_*`` model, database bundle, or options.

Paired ClairS execution is split at the expensive boundaries inherited from
``wf-somatic-variation``. Candidate extraction is exposed as
``somatic_paired_snv_candidate`` and records ``extract_pair_candidates`` command
metadata plus SNV, indel, hybrid, and candidate-BED artefact directories.
Pileup tensor creation and pileup prediction are exposed as
``somatic_paired_snv_pileup`` and are keyed by ``region_id``/``contig`` and
``variant_type`` so a failed chunk can be retried without rerunning candidate
extraction or unrelated chunks.
Full-alignment tensor creation and prediction are exposed separately as
``somatic_paired_snv_full_alignment``. This entry consumes the controller's
selected phased or unphased tumour/normal alignment pair, candidate BED and
variant artefacts, and ClairS model evidence, then emits full-alignment VCF
fragments with command, manifest, provenance, QC, and completion-marker
records. Final sort/filter/merge behavior remains outside this entry.
The first final-VCF boundary is ``somatic_paired_snv_merge``. It consumes
manifested pileup and full-alignment fragments plus a contig-order file, sorts
each fragment family with ClairS ``sort_vcf``, merges them with ClairS
``merge_vcf``, and emits a compressed/indexed paired somatic VCF with command,
manifest, provenance, QC, and completion-marker records. Haplotype filtering is
now a separate bounded capability and must not be hidden inside the merge.

Phase 4 task 33 adds ``somatic_paired_snv_haplotype_filter``. The entry
consumes controller-declared pileup/full-alignment VCFs, the unfiltered final
paired VCF, tumour haplotagged alignment, reference assets, and structured
``haplotype_filter_options``. It emits a filtered VCF/index plus command,
manifest, state, provenance, QC, log, and completion-marker records. The state
is explicit: ``completed`` when ClairS filtering and final merge succeed,
``skipped_disabled`` when policy disables filtering, and ``failed`` when the
filter command or final compression/indexing fails. The primary filtered
outputs are ``somatic_haplotype_filtered_vcf`` and
``somatic_haplotype_filtered_vcf_index``.

``shared_region_state`` is the only supported representation of paired shared
callable regions. Phase 4 task 24 adds ``-entry somatic_qc`` as the bounded
somatic QC task that intersects tumour and normal/control mosdepth-region BEDs
with an optional target BED, then emits ``somatic_shared_regions_bed``,
``somatic_rejected_regions_summary``, ``somatic_qc_manifest``,
``somatic_qc_metrics``, and ``somatic_provenance``. Paired SNV and paired SV
must wait for this state; caller workflows must not resurrect inherited
pairwise BED flow or HTML reporting. When bounded somatic QC produces zero
shared callable bases, the state is ``shared_region_empty``. That is a valid
terminal paired coverage outcome, not invalid evidence and not a retryable
missing-input state.

``paired_coverage_state`` records the pair-level result as ``pair_ready``,
``tumour_failed``, ``normal_failed``, ``both_failed``, or
``shared_region_empty``. Role-specific low-coverage states remain visible for
diagnosis, but only the affected pair is blocked.

``wf-human-variation`` bounded entries must emit task provenance and output
artefacts for the controller to project. They must not require dashboard/API
code to parse inherited Nextflow work directories, HTML reports, or implicit
caller output locations.

Task-Family Boundary
--------------------

Phase 4 task 8 registers somatic task families in the shared controller
contract: ``somatic_qc``, ``somatic_tumour_only_snv``,
``somatic_paired_snv``, ``somatic_germline_helper``, ``somatic_phasing``,
``somatic_haplotagging``, ``somatic_tumour_only_sv``,
``somatic_paired_sv``, ``somatic_methylation_aggregation``,
``somatic_differential_methylation``, ``somatic_annotation``, and
``somatic_export``.

Future ``wf-human-variation`` somatic entries must map to those bounded
families. They must not reintroduce a monolithic somatic workflow, a generic
``somatic_sv`` family that hides tumour-only versus paired readiness, or
hidden phasing/haplotagging side effects inside SNV callers. Somatic phasing
and haplotagging are maintained as explicit bounded entries with their own
state, policy, command, and provenance records.
EPI2ME HTML reporting outputs.

Shared Human-Variation Inputs
-----------------------------

Somatic execution reuses the maintained human-variation sample path. Existing
bounded ``mapping`` and ``sample_aggregation`` task provenance is projected by
Poikilognostikon into ``shared_role_artefacts`` for each ``tumour``,
``normal``, or ``control`` role. The required reusable artefacts are
``aggregate_xam`` and ``aggregate_xam_index``; ``mosdepth_summary`` and
``coverage_state`` are consumed when present. ``mosdepth_regions`` is required
for bounded somatic QC so shared callable regions can be represented as
explicit manifest evidence rather than caller-local BED side effects.

Future somatic entries must consume those shared artefacts. They must not run a
separate ingestion graph, remap role BAMs, perform a private per-role merge, or
hide role coverage behind inherited ``wf-somatic-variation`` directory
conventions.

Tumour-Only SNV Readiness
-------------------------

Phase 4 task 10 defines the controller-side readiness gate for future
``somatic_tumour_only_snv`` entries. ClairS-TO may be scheduled with a
``tumour`` role and without ``normal`` or ``control`` roles only when
Poikilognostikon records:

* tumour ``aggregate_xam`` and ``aggregate_xam_index`` from
  ``sample_aggregation``;
* ``clairs_to`` reference compatibility;
* basecaller/model compatibility for the tumour aggregate;
* ready ClairS-TO model and non-somatic database-bundle state;
* explicit target BED state, including ``optional_not_provided`` when no BED
  is supplied;
* structured allowlisted ``clairs_to_options`` and
  ``clairs_to_options_digest``.

The bounded workflow must consume this readiness state. It must not infer
tumour-only mode from missing ``bam_normal`` or accept free-form ClairS-TO shell
arguments.

Bounded ClairS-TO Calling
-------------------------

Phase 4 task 11 adds ``-entry somatic_tumour_only_snv`` as the maintained
ClairS-TO execution boundary. The entry consumes only the tumour role's
controller-projected aggregate alignment/index, reference FASTA/index, a
versioned ClairS-TO model directory, an explicit non-somatic database bundle,
optional target BED, optional hybrid candidate VCF, optional genotyping VCF,
and structured ``clairs_to_options`` plus ``clairs_to_options_digest``.

The inherited tumour-only command shape is retained as source evidence:
``run_clairs_to`` receives ``--tumor_bam_fn``, ``--ref_fn``, ``--platform`` for
the selected ClairS-TO model name, ``--output_dir``, thread and threshold
options, optional ``--bed_fn``, and optional
``--hybrid_mode_vcf_fn``/``--genotyping_mode_vcf_fn``. The old hidden
``CLAIR_DBS_PATH`` dependency is replaced by a controller-declared database
bundle directory whose digest is recorded in provenance.

The bounded output contract is machine-readable and restart-safe:
``somatic_snv_vcf``, ``somatic_snv_vcf_index``,
``somatic_tumour_only_snv_command_json``,
``somatic_tumour_only_snv_logs``,
``somatic_tumour_only_snv_manifest``, ``somatic_provenance``, and
``qc_stats``. The retained final data filename is
``<sample_id>.wf-somatic-snv.vcf.gz`` plus ``.tbi``. Inherited HTML reports,
publication hooks, IGV configuration, and ``bam_normal``-driven mode inference
remain excluded from this workflow contract.

Tumour-Only SV Readiness
------------------------

Phase 4 task 12 defines the maintained readiness gate for future
``somatic_tumour_only_sv`` entries. Severus may be scheduled with a ``tumour``
role and without ``normal`` or ``control`` roles only when Poikilognostikon
records:

* tumour ``aggregate_xam`` and ``aggregate_xam_index`` from
  ``sample_aggregation``;
* ``severus`` reference/genome-build compatibility independent of annotation
  being enabled;
* explicit PON state, including ``optional_not_provided`` when no Panel of
  Normals is supplied;
* explicit tandem-repeat BED state, including ``optional_not_provided`` when no
  TRF/VNTR BED is supplied;
* explicit segmental-duplication BED state, including ``optional_not_provided``
  while inherited SV annotation remains removed;
* ``severus_config_digest``;
* structured allowlisted ``severus_options`` and ``severus_options_digest``.

The inherited ``severus_args`` free-form override is not part of the bounded
contract. The inherited hidden defaults under ``WFSV_PON_PATH`` and
``WFSV_TRBED_PATH`` are source evidence only; future execution must use
controller-declared assets with reference compatibility and checksums, or an
explicit optional state. Tumour-only SV readiness must not infer mode from a
missing ``bam_normal`` parameter.

Versioned Somatic SV Assets
---------------------------

Phase 4 task 14 models PON TSVs, TRF/VNTR BEDs, and segmental-duplication BEDs
as versioned reference assets rather than bundled workflow conveniences. A
ready asset state must include an asset id, asset kind, path, SHA-256 checksum,
genome build, and source evidence. When a reference id is supplied it must
match the planned reference; when a reference genome build is known, the asset
genome build must match it.

The inherited somatic workflow used ``WFSV_PON_PATH/PoN_1000G_hg38.tsv.gz``,
``WFSV_TRBED_PATH/${genome_build}.trf.bed``, and hardcoded
``data/hg38.segdups.bed.gz`` / ``.tbi`` assets. Those values are source
evidence only. The maintained bounded Severus entry must either receive
controller-declared staged assets or record ``optional_not_provided``; it must
not restore the hidden PON, TRF, or ``SEG_DUP`` annotation fallback.

Bounded Somatic Annotation
--------------------------

Phase 4 task 15 adds ``-entry somatic_annotation`` as the maintained somatic
annotation boundary. It consumes a controller-declared somatic SNV or SV VCF
and index, the source output artefact id, analysis intent, role snapshot,
reference id/build, a versioned SnpEff database, optional ClinVar VCF/index,
optional related SIFT annotation state, structured
``somatic_annotation_options``, and explicit config/container digests.

The bounded entry preserves the useful inherited SnpEff/SnpSift route while
removing the inherited coupling: caller workflows no longer run annotation as
a side effect, and the entry does not read ``CLINVAR_PATH``, call
``getGenome``, use ``SEG_DUP`` or hardcoded ``hg38.segdups`` assets, publish
HTML, or create IGV/report artefacts. Outputs are
``somatic_annotated_vcf``, ``somatic_annotated_vcf_index``,
``somatic_clinvar_vcf``, ``somatic_clinvar_vcf_index``,
``somatic_annotation_manifest``, ``somatic_annotation_command_json``,
``somatic_provenance``, and ``qc_stats``.

Bounded Somatic Methylation Aggregation
---------------------------------------

Phase 4 task 16 adds ``-entry somatic_methylation_aggregation`` as the
maintained role-specific modkit aggregation boundary. It consumes one
controller-declared ``tumour``, ``normal``, or ``control`` aggregate XAM and
index, reference FASTA/index, reference genome build, role snapshot,
structured ``somatic_methylation_options``, ``modkit_config_digest``,
``somatic_methylation_options_digest``, and container digest.

The bounded entry preserves useful inherited modkit operations:
``workflow-glue check_valid_modbam``, ``modkit sample-probs``,
``modkit pileup``, ``modkit summary``, bedMethyl indexing, DSS input
projection, and BigWig conversion. It does not run DSS, import
``workflow-glue report_mod``, publish MOD HTML reports, use
``params.modkit_args``, infer tumour-only mode from missing ``bam_normal``, or
use ``OPTIONAL_FILE`` sentinels. Outputs are ``somatic_bedmethyl``,
``somatic_bedmethyl_index``, ``somatic_bigwig``, ``somatic_mod_summary``,
``somatic_dss_input_tsv``, ``somatic_methylation_aggregation_manifest``,
``somatic_methylation_aggregation_command_json``,
``somatic_methylation_aggregation_log``, ``somatic_provenance``, and
``qc_stats``.

Bounded Tumour-Only Severus
---------------------------

Phase 4 task 13 adds ``-entry somatic_tumour_only_sv`` as the maintained
tumour-only Severus execution boundary. The entry consumes only the tumour
role's controller-projected aggregate alignment/index, reference FASTA/index,
explicit optional PON and TRF/VNTR BED paths, and structured
``severus_options`` plus ``severus_options_digest``.

The bounded entry preserves the inherited useful command shape,
``severus --target-bam tumor.bam --out-dir severus-output --threads ...``,
while replacing free-form ``severus_args`` with allowlisted options for the
default preset flags, VAF threshold, minimum SV length, and minimum support.
PON and TRF/VNTR BED inputs are passed only when the controller declares them.
There is no fallback to hidden container-local assets.

Phase 4 task 17 makes structured somatic tool option objects part of task
identity. The controller must supply ``clairs_to_options_digest``,
``severus_options_digest``, or ``somatic_methylation_options_digest`` for the
relevant bounded entry; the digest is written to the manifest and provenance
input checksum block. Free-form inherited surfaces including ``severus_args``,
``modkit_args``, ClairS shell fragments, DSS/R argument fragments, and
phasing-tool ``*_args`` remain outside the maintained contract.

The bounded output contract is machine-readable and restart-safe:
``somatic_sv_vcf``, ``somatic_sv_vcf_index``, ``somatic_sv_raw_directory``,
``somatic_tumour_only_sv_command_json``,
``somatic_tumour_only_sv_manifest``, ``somatic_provenance``, and
``qc_stats``. The retained final data filename is
``<sample_id>.wf-somatic-sv.vcf.gz`` plus ``.tbi``. Inherited SV HTML reports,
publication hooks, IGV configuration, annotation side effects, and
``bam_normal``-driven mode inference remain excluded.

Bounded Paired Severus
----------------------

Phase 4 task 34 adds ``-entry somatic_paired_sv`` as the maintained paired
Severus execution boundary. The entry consumes explicit ``pair_id``,
``tumour_sample_id``, ``normal_or_control_sample_id``, ``paired_role``,
``role_snapshot_digest``, and ``relationship_snapshot_digest`` state plus
tumour and normal/control aggregate alignment/index artefacts from
``sample_aggregation``. It also requires reference FASTA/index evidence, a
TRF/VNTR BED and digest, ``severus_config_digest``,
``severus_options_digest``, structured ``severus_options``, and a runtime
``container_digest``. PON evidence remains optional but explicit.

The retained paired command shape is
``severus --target-bam tumor.bam --control-bam normal.bam --out-dir severus-output``.
The bounded entry writes ``somatic_paired_sv_command_json`` before execution,
normalises the raw Severus VCF to
``<pair_id>.wf-somatic-sv.vcf.gz`` plus ``.tbi``, copies the raw
``severus-output`` directory, and emits ``somatic_paired_sv_manifest``,
``somatic_provenance``, and ``qc_stats``. Paired SV is separate from
``somatic_tumour_only_sv``: it does not infer normal/control state from
``bam_normal``, does not use ``OPTIONAL_FILE``, does not restore
``WFSV_PON_PATH`` or ``WFSV_TRBED_PATH`` hidden defaults, and does not publish
SV HTML, IGV, or annotation side-effect outputs.

Bounded Differential Methylation
--------------------------------

Phase 4 task 35 adds ``-entry somatic_differential_methylation`` as the
maintained paired DSS execution boundary. The entry consumes explicit
``pair_id``, tumour and normal/control sample ids, role and relationship
snapshot digests, reference id/build, one ``modification_code``, the tumour and
normal/control ``somatic_dss_input_tsv`` outputs from completed role-specific
``somatic_methylation_aggregation`` tasks, input digests,
``dss_config_digest``, ``dss_options_digest``, structured ``dss_options``,
``r_bioconductor_lock_digest``, and container digest.

The bounded entry preserves the useful inherited DSS method shape:
``makeBSseqData`` over tumour and normal DSS inputs, ``DMLtest``, ``callDML``,
and ``callDMR``. It changes the operational contract: DSS failures are not
reported as successful empty analyses, tumour-only methylation does not schedule
DSS, and paired DSS is launched only when both role-specific input TSVs exist.
Outputs are ``somatic_dml_tsv``, ``somatic_dmr_tsv``,
``somatic_differential_methylation_manifest``,
``somatic_differential_methylation_command_json``,
``somatic_differential_methylation_log``, ``somatic_r_versions``,
``somatic_provenance``, and ``qc_stats``. Inherited MOD HTML reports,
``workflow-glue report_mod``, ``diff_mod`` global branching,
``params.dss_threads``, and free-form DSS/R argument fragments remain outside
the maintained contract.
