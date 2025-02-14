# SPDX-FileCopyrightText: 2024 Helmholtz Centre for Environmental Research GmbH - UFZ
#
# SPDX-License-Identifier: LicenseRef-UFZ-GPL-3.0-or-later

# Use an official PostgreSQL image as the base image
FROM postgres:13

# Set environment variables
ENV POSTGRES_DB lmdb
ENV POSTGRES_USER lmdb_adm
ENV POSTGRES_PASSWORD BJSeVYMK6QaDE3eVfJEB

# Copy scripts and data
COPY ddl /home/lmdb/ddl
COPY data /home/lmdb/data
COPY journal /home/lmdb/journal

# Copy the build script into the initdb entrypoint for automatic execution
COPY build.sql /docker-entrypoint-initdb.d/

# Expose the default PostgreSQL port
EXPOSE 5400
