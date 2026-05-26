Keyed Joins
===========

Bounded ``humvar3`` entries must not use global ``collect()`` or broad unkeyed
``combine()`` operations to decide task readiness. Joins must be scoped to the
smallest correct boundary:

* per sample: ``sample_id``;
* per sample/reference: ``sample_id`` plus ``reference_id``;
* per task: the deterministic ``task_key``.

The helper functions in ``lib/keyed_joins.nf`` provide the Nextflow-side keying
convention for new bounded entries. The Python controller owns equivalent
controller-side keys in ``gnostikon_workflow_control.join_keys``.

Per-sample state must remain partial and concurrent. A join for one sample in
``variant_calling`` must not wait for another sample that is still
``basecalling`` or ``mapping``.

Allowed Uses
------------

``collect()`` remains acceptable only inside a bounded task when all values are
already scoped to that task key, for example collecting contig shards for one
sample/reference result. It must not be used to wait for all samples, all
flowcells, or all requested analysis families.

``combine()`` must specify a key or operate on a singleton value channel.
Unkeyed Cartesian joins are not acceptable for sample, reference, or task
state.

Compatibility Debt
------------------

The imported ``main.nf`` compatibility graph still contains whole-run joins for
legacy publication, annotation, and packaging. Do not copy those patterns into
bounded entries. Retire them as the relevant family is moved behind
controller-led execution:

* ``sample_aggregation`` owns per-sample/per-reference aggregate refresh;
* ``variant_calling`` owns SNP/SV/phasing/annotation joins;
* ``methylation``, ``cnv``, and ``str`` own their family-specific joins;
* ``reporting`` owns publication/package reductions from manifest-indexed
  outputs.

Review Checklist
----------------

For every new bounded entry:

1. Identify its join key before writing channel code.
2. Use keyed ``join``/``combine(..., by: ...)`` or pre-keyed tuples.
3. Keep ``collect()`` inside a task-key scope.
4. Record any intentional singleton value channel.
5. Reject changes that add all-sample or all-reference barriers.
