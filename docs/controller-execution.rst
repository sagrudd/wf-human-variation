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
by STR, Spectre, or reporting side effects.

Task 18 adds the bounded structural-variant entry as ``variant_mode=sv``:

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

Task 19 adds the bounded CNV entry with explicit Spectre and QDNAseq modes:

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
