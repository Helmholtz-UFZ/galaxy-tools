<!--
SPDX-FileCopyrightText: 2025 Helmholtz Centre for Environmental Research GmbH - UFZ

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Chemical Formula Library

## Execution

```bash
# Build the image from the Dockerfile in .
sudo docker build -t cflib_image .
```

Run the container listening to a different port (e.g. 5431) if you want to run
it in parallel with another database container (e.g. lmdb container). Remember
to also change any port settings to the new port.

```bash
# Run a container from the image
sudo docker run -p 5431:5432 --name cflib_container -d cflib_image
```

Please be aware, that importing all the data will take a little time depending
on the capacities of the executing machine (few minutes). The database is not
reachable via `psql` during import. The command will result in an error.

```bash
# Connect to the database via the container
sudo docker exec -it cflib_container psql -U cflib_adm cflib
```

```bash
# Connect to the database in the container directly
psql -h localhost -p 5431 -U cflib_adm cflib
```

```bash
# Stop the container
sudo docker stop cflib_container
```

```bash
# Start an already stopped container
sudo docker start cflib_container
```

```bash
# Remove the container
sudo docker rm cflib_container
```

## Database User

Admin User: `cflib_adm` with password `BJSeVYMK6QaDE3eVfJEB`

Read-Write User: `cflib_rw` with password `SSeTjhTE42ba9kgjDrUY`

Read-Only User: `cflib_ro` with password `z7zDjfZbTQq8QU6dTHGL`
