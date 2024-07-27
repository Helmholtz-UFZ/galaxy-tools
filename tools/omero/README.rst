Admins can configure a set of OMERO users that users can choose from in the data table `omero_servers.loc`.
For instance an entry:

```
demo	OMERO demo server	demo.openmicroscopy.org	4064
```

in the user_preferences file the admin needs to define a possibility for users to enter username and password.
The name of the entry need to be the unique value from the data table prefixed by `omero_`::

    omero_demo:
        description: Credentials for OMERO demo server
        inputs:
            - name: username
              label: Username
              type: text
              required: False
            - name: password
              label: Password
              type: secret
              store: vault
              required: True

For users entering a manual omero server an entry::

    omero:
        description: Custom OMERO server credentials
        inputs:
            - name: username
              label: Username
              type: text
              required: False
            - name: password
              label: Password
              type: secret
              store: vault
              required: True
