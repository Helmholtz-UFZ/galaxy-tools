![Status](https://img.shields.io/badge/status-active-brightgreen)
![Build](https://img.shields.io/github/actions/workflow/status/Helmholtz-UFZ/galaxy-tools/ci.yaml)
![Issues](https://img.shields.io/github/issues/Helmholtz-UFZ/galaxy-tools)
![Pull Requests](https://img.shields.io/github/issues-pr/Helmholtz-UFZ/galaxy-tools)

# Galaxy UFZ - Tool Wrappers Collection

<img align="top" width="755" height="220" alt="UFZ-logo" src="./images/UFZ-logo.jpg" />


This repository contains tools mantained within the UFZ and that can be installed and used inside any Galaxy instance. 

**Contributions are welcome**. Please open an issue or a PR in case you want to contribute to the tool list.


## List of Tools

### Time series data

Tools to analyze time-series data for environmental sensor data

- [**SaQC**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/saqc/saqc/2.6.0+galaxy0) with SaQC

### OMERO-suite

A set of tools to import image and metadata in OMERO using Galaxy

- [**OMERO Image Import**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/omero_import/omero_import/5.21.2+galaxy0) with omero-py
- [**OMERO IDs**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/omero_filter/omero_filter/5.21.2+galaxy0) with ezomero
- [**OMERO get IDs**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/omero_get_id/omero_get_id/5.21.2+galaxy0) with ezomero
- [**OMERO get Object**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/omero_get_value/omero_get_value/5.21.2+galaxy0) with ezomero
- [**OMERO ROI Import**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/omero_roi_import/omero_roi_import/5.21.2+galaxy0) with ezomero
- [**OMERO Metadata Import**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/omero_metadata_import/omero_metadata_import/5.21.2+galaxy1) with ezomero
- [**OMERO Dataset to Plate**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/omero_dataset_to_plate/omero_dataset_to_plate/5.21.2+galaxy4) with ezomero

### Chemoinformatics

Tools to molecular structures of chemicals with multiple targets.

- [**deepFPlearn train**](https://toolshed.g2.bx.psu.edu/repositories/5b85c6d3751502a1) with deepFPlearn
- [**deepFPlearn predict**](https://toolshed.g2.bx.psu.edu/repositories/e393abc15e430eff) with deepFPlearn

### Toxicology and Ecotoxicology
Toxicity prediction and dose response curves
- [**QSAR Baseline Calculator**](https://toolshed.g2.bx.psu.edu/repositories/0ad301feb4e0e566) with pandas
- [**Dose Response Modelling**](https://toolshed.g2.bx.psu.edu/view/ufz/dose_response_analysis_tool) with drc

### Data Wrangling
Tools for data conversion and data wrangling
- [**Excel to Tabular**](https://usegalaxy.eu/root?tool_id=toolshed.g2.bx.psu.edu/repos/ufz/xlsx2tsv/xlsx2tsv/0.2.0+galaxy0) with pandas

### Related Matherial
#### OMERO
- [Galaxy Training Matherial for the OMERO-suite](https://training.galaxyproject.org/training-material/topics/imaging/tutorials/omero-suite/tutorial.html)
- [OMERO-suite Poster Publication on Zenodo](https://zenodo.org/records/14975462/files/2025_AHM_Galaxy_OMERO-1.pdf)
#### Time Series Anaylsis
- [SaQC publication](https://www.sciencedirect.com/science/article/pii/S1364815223001950?via%3Dihub)
- [SaQC software](https://helmholtz.software/software/saqc)
#### Chemoinformatics
- [deepFPlearn repo](https://github.com/yigbt/deepFPlearn)
