Idempotent Tasks
================

``humvar3`` is being adapted so work can be reused while new sample, run, POD5,
BAM, and analysis artefacts arrive. Any task-family refactor must therefore
make task identity, internal output paths, and completion state deterministic.
The allowed top-level families are defined in
``docs/bounded-task-families.rst`` and ``lib/task_families.nf``.

Contract
--------

Every bounded task must define:

* a deterministic ``task_key`` derived only from stable identifiers, input
  content digests, reference identifiers, and command-affecting configuration;
* an internal task-cache directory derived from that ``task_key``;
* declared output paths under that task-cache directory;
* a completion marker named ``.gnostikon_task_complete.json`` written only
  after all required outputs exist and validate;
* a manifest or runtime event projection that records output paths and the
  completion marker path.

Existing files are not enough to prove that a task is reusable. Reuse requires
a successful completion marker whose ``task_key`` matches the current logical
task and whose declared required outputs still exist.

Path Rules
----------

Internal reusable products must be written below:

.. code-block:: text

   <out_dir>/task-cache/<task_family>/<digest-prefix>/<task-digest>/

User-facing publication remains a separate output concern. Published filenames
may continue to use existing workflow display labels while internal task-cache
paths use stable ids and digests.

Task Key Inputs
---------------

Task keys must not include transient executor state, attempt number, wall-clock
time, host name, Nextflow work directory, barcode folder, sample display name,
or read-group label. These values can be logged as provenance, but they must not
control logical task reuse.

Task keys should include:

* ``sample_id`` when the work is sample-scoped;
* optional ``project``, ``flowcell``, or ``run_id`` only when they change task
  semantics;
* reference id or digest for reference-dependent work;
* input artefact digest or sorted digest list;
* command-affecting configuration hash.

Nextflow Maintenance
--------------------

The helper functions in ``lib/task_idempotency.nf`` provide the shared
deterministic key and path convention for future Nextflow task-family work.
When a process is refactored into a bounded reusable task, update its process
body, output declarations, documentation, and tests together.

The Python controller is responsible for deciding whether to launch or refresh
the task. A Nextflow entry should trust the bounded params file it receives and
should not scan the project for additional work.

Dynamic Scheduling
------------------

Schedulers must check for a valid completion marker before queuing work. If new
data arrives, only task keys affected by the new input or changed configuration
should be planned. Successful old work with the same task key remains reusable.
