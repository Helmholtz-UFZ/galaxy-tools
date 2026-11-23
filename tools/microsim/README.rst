Dumux Pseudo-3D Stokes - Galaxy tool
=====================================

A Galaxy wrapper around the **Pseudo-3D-Stokes module for varying apertures**
(https://git.iws.uni-stuttgart.de/krachdd/pseudo3D_stokes), a DuMux-based
simulation module for planning, improving, and interpreting microfluidic
experiments via Stokes/Brinkman flow simulation on 2D pore/aperture geometries.

See ``test.xml``'s ``<help>`` section for the full user-facing description,
citation, and contact information.

Layout
------

- ``test.xml`` - the Galaxy tool definition.
- ``test-data/`` - fixtures used by the ``<tests>`` block in ``test.xml``
  (``hx_singlePrecipitate_full.pgm`` input, ``geometry-00001.vtu`` expected output).
- ``example_data/`` - sample PGM geometries of varying sizes for trying the tool
  out interactively (not used by the automated test).

Requirements
------------

The tool runs inside the ``microsim-pseudo3d-stokes`` Docker image, built from
``../docker`` (see ``../docker/README.md``) - it bundles the compiled DuMux
solver, ``runStokesGeneric.py``, and their Python dependencies. The image must
be built and available to whichever Galaxy instance runs this tool (see
``<container>`` in ``test.xml``'s ``<requirements>`` for the exact image
reference).

Local development
------------------

From this directory, with the ``microsim-pseudo3d-stokes`` image already built
(see ``../docker/buildDockerImage.sh``) and docker permissions set up::

    planemo lint test.xml            # style/quality checks
    planemo test --docker test.xml   # runs the real simulation in the container
    planemo serve --docker test.xml  # local Galaxy instance to click through the form

Publishing / deployment
------------------------

This tool is not yet published to a Tool Shed. Before doing so:

- The ``microsim-pseudo3d-stokes`` image needs to be hosted somewhere the
  target Galaxy instance's compute nodes can pull it from, at a pinned
  (non-``:latest``) tag.
- A ``.shed.yml`` is needed to create/push the Tool Shed repository.

See the tool's ``<help>`` section and commit history for more context.
