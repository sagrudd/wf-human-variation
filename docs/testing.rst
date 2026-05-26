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
