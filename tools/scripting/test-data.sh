#!/bin/bash

set -x

singularity pull --dir /tmp docker://python:3.10-slim
singularity pull --dir /tmp docker://rocker/tidyverse