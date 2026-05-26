Controller-Led Execution
========================

``humvar3`` must not evolve by making ``main.nf`` a larger monolithic DAG.
The target operating model is:

1. The Python controller observes runtime events and projects manifest state.
2. The controller decides whether a bounded task family should launch, skip, or
   refresh.
3. Nextflow executes the selected bounded unit.
4. The bounded unit writes declared outputs and a completion marker.
5. The controller records task and output events, then plans any newly unblocked
   downstream family.

Nextflow is therefore an execution backend for bounded work. It should not be
responsible for discovering unrelated new samples, waiting for all samples, or
deciding global analysis state.

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
     --output mapped_bam=outputs/reads.sorted.bam

This writes a bounded params file containing:

* ``task_family``;
* ``task_key``;
* ``task_dir`` / ``task_cache_dir``;
* ``completion_marker_path``;
* declared ``output_paths``.

The command skips execution when the completion marker is valid for the same
task key unless the controller requests ``--force-refresh``.

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
* ``main.nf`` remains a compatibility path until the bounded entries replace
  the imported launch-time workflow behavior.
