# OMERO suite toolbox

[Galaxy Training Material to the OMERO suite
](https://training.galaxyproject.org/training-material/topics/imaging/tutorials/omero-suite/tutorial.html)

## Overview on the OMERO set-up process for Tool Testing

**Installed dependecies:**
- zeroc-ice==3.6.5
- omero-py==5.19.4 
- omero-metadata==0.13.0 
- pandas<3.0

**Final data structure in OMERO:**

```
default (GroupID:1)

- test_prj (Project:ID1)

    - test_dts (Dataset:ID1)

        - sample_image.jpg (Image:ID1)

        - sample_image_2.jpg (Image:ID2)


test_hcs_dts (Dataset:ID2)

    - sample_A03_image.jpg (Image:ID3)

    - sample_H11_image.jpg (Image:ID4)
```

**Annotations and Tags:**

sample_image.jpg (Image:ID1)

    - TagAnnotation:1 (Name: test_tag Description: "description of my_tag")

test_dts (Dataset:ID1)

    - Table (OriginalFile:113, dummy-bulkmap.csv)
    - Table (OriginalFile:114, dummy-bulkmap.csv)
    - Annotation (OriginalFile:115, key-value pairs, dummy-bulkmap.yml)

**Uploaded File:**

    - attachement.tsv  (OriginalFile:110, FileAnnotation:2)
    - attachement.tsv  (OriginalFile:111, FileAnnotation:3)
    - attachement.tsv  (OriginalFile:112, FileAnnotation:4)

**IMPORTANT NOTICE:**

Tool testing can add additional files an image to the Data Structure. 

As example, OMERO import test will add four additional images with ID:5, 6, 7, 8.

This is also valid for OMERO metadata import or any other tool testing data upload in OMERO.

Set-up your tests accordingly.

## Old approach to set up user credentials on Galaxy to connect to other OMERO instance (pre 25.1 Galaxy release)

To enable users to set their credentials for this tool,
make sure the file `config/user_preferences_extra.yml` has the following section:

```
    omero_account:
        description: Your OMERO instance connection credentials
        inputs:
            - name: username
              label: Username
              type: text
              required: False
            - name: password
              label: Password
              type:  password
              required: False
