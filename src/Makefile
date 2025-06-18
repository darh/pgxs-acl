# Name of the extension
EXTENSION  = ac

# SQL file containing extension objects and functions
DATA       = ac--0.0.1.sql

# Path to the pg_config executable
PG_CONFIG ?= pg_config

# Get the PostgreSQL Extension Makefile from pg_config
PGXS      := $(shell $(PG_CONFIG) --pgxs)

REGRESS    = test_check

REGRESS_OPTS += --user=$(POSTGRES_USER)

# Include the PostgreSQL Extension Makefile
include $(PGXS)


