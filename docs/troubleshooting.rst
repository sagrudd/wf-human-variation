Troubleshooting
===============

Input Is Rejected
-----------------

Check:

* whether ``--bam`` points to a file or supported directory layout;
* whether the extension is BAM, CRAM, or uBAM-compatible;
* whether a MinKNOW-style experiment directory also needs ``--sample_name``;
* whether files appear at mixed directory depths;
* whether only one sample is being ingressed.

Coverage Is Too Low
-------------------

The workflow uses ``--bam_min_coverage`` to decide whether downstream analysis
should proceed. Low coverage is an explicit terminal sample condition:
``rejected_low_coverage``. Downstream analysis is skipped, and the workflow
exits with a non-zero status so orchestration layers do not mistake the result
for a successful analysis. Poikilognostikon should present low-coverage state
from the shared manifest, not from a workflow-generated HTML report.

Reference Does Not Match Input
------------------------------

The workflow checks input alignment headers against the requested reference and
can realign where needed. CRAM input also requires compatible reference access.

Annotation Fails Or Is Skipped
------------------------------

Annotation depends on supported genome-build resources. Unsupported references
can block annotation even when raw variant calling would otherwise be possible.

STR Or Phased Output Runs More Work Than Expected
-------------------------------------------------

STR and phased outputs rely on haplotagging. Haplotagging is currently
implemented inside the SNP route, so enabling STR or phasing can cause SNP work
to run even when ``--snp`` was not explicitly selected in the static
compatibility graph.

For bounded ``humvar3`` entries, this behavior should appear as visible
``task.blocked`` or ``task.planned`` state: STR requires
``haplotagged_contig_bams``, and the controller decides whether to plan the
internal ``variant_calling`` prerequisite or wait for an existing output.

QDNAseq Requires BAM-Compatible Input
-------------------------------------

QDNAseq CNV mode does not operate on every XAM format. The workflow may convert
or force BAM-compatible intermediate output for this branch.

Modified-Base Output Is Missing
-------------------------------

Modified-base analysis requires BAM tags such as ``MM`` and ``ML``. If tags are
not present, modified-base output may be skipped while other requested analyses
continue.
