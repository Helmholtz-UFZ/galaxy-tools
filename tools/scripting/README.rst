Note to admins: 
===============

These tool allow users to execute arbitrary scripts in containers
(with singularity or apptainer). The interpreter (python, Rscript,
bash, ...) and the containers is configured by the admin using the
``scripting_images`` data table.

A basic level of security comes by the execution in containers.
Additional parameters that should be passed to the container engine
can be configured.

Admins should consider the following points:

- Passing the ``--cleanenv`` variable is certainy a good idea.
- The tool will mount the galaxy files dir for reading and only the
  job working dir should be writable (might depend on your configuraion).
  It's advisable to use the ``--no-mount`` option to disable additional
  mounts that might be writable.
- Maybe disable or limit network usage, eg. for singularity ``--network none``

This tool has been inspired by the [scriptrunner](https://github.com/ARTbio/docker-scriptrunner/blob/master/scriptrunner.xml) tool
which works with docker.
