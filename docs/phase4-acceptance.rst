Phase 4 Somatic Foundation Acceptance
=====================================

This page defines the minimum gate for treating phase-4 tasks 1-20 as the
tumour-only and general somatic foundation inside the
Poikilognostikon-maintained ``wf-human-variation`` fork.

Release Decision
----------------

Phase 4 tasks 1-20 are implementation-complete for local contract review only.

Release status: not release-accepted for customer or production use until owned
ARM64 image-build evidence and scientific validation evidence are supplied.

The current dirty-worktree ``wf-human-variation`` fork candidate is:

.. code-block:: text

   b1a5a78ec9c02de276f01dc8608096db93a87e91

This is not an accepted fork pin while phase-4 files remain uncommitted. The
accepted ``wf-human-variation`` fork commit is the future committed phase-4
revision that passes this gate. Poikilognostikon must pin
``workflows/wf-human-variation`` to that exact commit. A dirty submodule
worktree, uncommitted bounded entry, or missing validation evidence blocks
acceptance.

This gate covers only tasks 1-20. Paired tumour-normal task families remain
phase 4 tasks 21-40 and are not accepted by this page.

Required Somatic Foundation Contracts
-------------------------------------

The tasks 1-20 foundation requires these controller-visible contracts:

.. list-table::
   :header-rows: 1

   * - Contract
     - Required surface for this gate
   * - ``somatic_qc``
     - Controller/manifest prerequisite and shared-role artefact state.
   * - ``somatic_tumour_only_snv``
     - Bounded ``-entry somatic_tumour_only_snv``.
   * - ``somatic_tumour_only_sv``
     - Bounded ``-entry somatic_tumour_only_sv``.
   * - ``somatic_methylation_aggregation``
     - Bounded ``-entry somatic_methylation_aggregation``.
   * - ``somatic_annotation``
     - Bounded ``-entry somatic_annotation``.
   * - ``somatic_export``
     - Controller/manifest export state without HTML reports.

``somatic_qc`` and ``somatic_export`` are accepted here as controller and
manifest contracts only. If either becomes a runtime Nextflow entry later, that
entry must pass the same bounded task, provenance, documentation, and container
evidence rules before release.

Minimum Local Gate
------------------

Before advancing the Poikilognostikon submodule pin for a phase-4 tasks 1-20
candidate, run:

.. code-block:: bash

   python -m unittest discover -s tests -v
   python -m sphinx -W -b html docs docs/_build/html
   python -m json.tool nextflow_schema.json >/tmp/wf-human-variation-nextflow-schema.json

The gate must include:

* ``tests/test_bounded_entry_contract.py`` for bounded somatic entry shape,
  retained output contracts, structured options, and provenance markers;
* ``tests/test_phase2_synthetic_contracts.py`` for tiny synthetic fixture
  contracts and public HTML report absence;
* Poikilognostikon tests for somatic analysis intents, sample roles, somatic manifest projection,
  tumour-only readiness, duplicate aggregate artefacts, missing PON fallback,
  ``tumour_rejected_low_coverage``, scheduling, and
  completion-marker reuse;
* ``gnostikon-workflow-control`` tests for somatic task families, reference
  compatibility, somatic reference assets, tumour-only SNV/SV readiness,
  annotation readiness, methylation readiness, structured tool options,
  idempotency, and bounded launch planning.

Required ARM64 And Container Evidence
-------------------------------------

Release acceptance requires owned-image evidence for these tumour-only/general
somatic runtime images:

.. list-table::
   :header-rows: 1

   * - Image family
     - Required evidence
   * - ``poikilognostikon-somatic-hts``
     - HTS/QC tool versions, shared-region or coverage helper evidence,
       immutable digest, and smoke-test output.
   * - ``poikilognostikon-somatic-clairs-to``
     - ClairS-TO version/source commit, AFF/NEG model checksums, model table
       checksum, database bundle checksum, immutable digest, and smoke-test
       output.
   * - ``poikilognostikon-somatic-severus``
     - Severus version/source commit, Python/native dependency probes,
       PON/TRF/segmental-duplication asset checks, immutable digest, and
       smoke-test output.
   * - ``poikilognostikon-somatic-modkit``
     - Modkit version, HTS helper versions, bedMethyl/BigWig smoke-test
       output, immutable digest, and provenance capture.
   * - ``poikilognostikon-somatic-annotation``
     - SnpEff/SnpSift and OpenJDK versions, SnpEff database and ClinVar/SIFT
       asset checksums, immutable digest, and annotation smoke-test output.
   * - ``poikilognostikon-somatic-helpers``
     - Retained helper versions or source checksums, import/version probes,
       immutable digest, and deletion boundary evidence.

Every accepted runtime image must have ``linux/amd64`` and ``linux/arm64``
build records, immutable image digests, version probe output, executable smoke-test output,
and a committed image manifest or bill of materials. The
owning image plan is ``phase-4-somatic-container-plan.md`` in the
Poikilognostikon repository. The method compatibility register is
``wf-human-variation-method-compatibilities.md``.

The paired-specific ``poikilognostikon-somatic-clairs``,
``poikilognostikon-somatic-clair3-helper``,
``poikilognostikon-somatic-phasing``, and ``poikilognostikon-somatic-dss``
images remain phase 4 tasks 21-40 release blockers and are not accepted by
this tasks 1-20 gate.

Scientific Validation Items
---------------------------

The following items are release blockers even when local contract tests pass:

Scientific validation remains unresolved for ClairS-TO tumour-only
concordance, Severus tumour-only SV concordance, modkit role aggregation
concordance, SnpEff/SnpSift somatic annotation correctness, reference asset
compatibility, and low-coverage state handling.

* ClairS-TO tumour-only SNV/indel calling must be concordance-tested against
  reviewed ``wf-somatic-variation`` behaviour and selected truth cases.
* ClairS-TO false-positive control behaviour must be reviewed with and without
  explicit target BED and database-bundle assets.
* Severus tumour-only SV calling must be concordance-tested with explicit PON,
  no-PON, TRF/VNTR BED, and segmental-duplication asset states.
* Modkit role aggregation must be checked against known modified-base fixtures
  for bedMethyl, BigWig, summary, and DSS-input TSV shape.
* SnpEff/SnpSift annotation must be checked against a known somatic SNV/SV VCF
  and expected ClinVar/SIFT output shape.
* Reference/genome-build validation must be checked for accepted, missing, and
  incompatible assets.
* ``tumour_rejected_low_coverage`` must be validated as a blocked analysis
  state, not a successful empty result.

Release Blocking Regressions
----------------------------

Any of these changes blocks phase-4 tasks 1-20 acceptance:

* somatic scheduling from filenames, aliases, or ``bam_normal`` absence rather
  than ``analysis_intent_id``, ``sample_id``, role snapshots, reference ids,
  and manifest readiness records;
* treating ``somatic_small_variant`` or ``somatic_structural_variant``
  capability labels as executable task families;
* duplicate somatic ingress, mapping, or sample aggregation graphs;
* hidden normal/control requirements in tumour-only SNV, SV, methylation, or
  annotation paths;
* inherited ONT runtime containers, sha-like tags, hidden PON/TRF/segmental
  duplication defaults, or container-local database assets as release pins;
* free-form ``severus_args``, ``modkit_args``, ClairS shell fragments, DSS/R
  fragments, or phasing-tool ``*_args``;
* HTML reports, IGV surfaces, EPI2ME Desktop metadata, telemetry, or
  report-only Python on the maintained runtime path;
* ``OPTIONAL_FILE`` sentinel leakage into controller contracts;
* global ``collect()``, broad or unkeyed ``combine()``, ``first()``, or
  ``groupTuple()`` readiness barriers in bounded somatic entries;
* missing container digest, model checksum, asset checksum, option digest,
  command argument, input checksum, output artefact, or completion-marker provenance;
* customer or production claims for paired tumour-normal semantics before
  tasks 21-40 pass their own acceptance gate.
