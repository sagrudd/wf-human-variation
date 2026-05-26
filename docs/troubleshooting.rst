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
should proceed. Low coverage can produce failure reports or stop requested
analysis depending on the branch. When changing this behavior, update the
maintenance and outputs documentation.

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
to run even when ``--snp`` was not explicitly selected.

QDNAseq Requires BAM-Compatible Input
-------------------------------------

QDNAseq CNV mode does not operate on every XAM format. The workflow may convert
or force BAM-compatible intermediate output for this branch.

Modified-Base Output Is Missing
-------------------------------

Modified-base analysis requires BAM tags such as ``MM`` and ``ML``. If tags are
not present, modified-base output may be skipped while other requested analyses
continue.
