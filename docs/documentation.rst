Documentation Maintenance
=========================

Canonical Documentation
-----------------------

The canonical documentation is the Sphinx tree under ``docs/``. Read the Docs
builds this tree using ``.readthedocs.yaml`` and ``docs/conf.py``.

The old Markdown fragment documentation has been removed. Do not reintroduce
``docs/01_*.md`` through ``docs/12_*.md`` as the documentation source.

Scope Rules
-----------

This repository documents ``wf-human-variation`` only. Keep the content focused
on:

* workflow architecture;
* inputs and outputs;
* subworkflow behavior;
* parameters and schemas;
* testing and maintenance;
* operational caveats and troubleshooting.

Do not add Poikilognostikon product documentation, migration planning, or
runtime-controller documentation to this Sphinx tree.

Build Locally
-------------

.. code-block:: bash

   python -m sphinx -W -b html docs docs/_build/html

Warnings should be treated as documentation failures.

Documentation Review Checklist
------------------------------

Before merging a change:

1. Confirm every behavior change has a documentation update.
2. Confirm new parameters are documented and present in the schema.
3. Confirm changed outputs are documented and present in the output definition.
4. Confirm architecture or subworkflow coupling changes are explained.
5. Build the docs with warnings as errors.
