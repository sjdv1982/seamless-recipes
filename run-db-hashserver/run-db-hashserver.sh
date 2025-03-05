#!/bin/bash
#
# Run a database and hashserver inside a conda environment
# The conda environment can be built from run-db-hashserver-environment.yaml,
#  (using conda env create --file run-db-hashserver-environment.yaml)
#  and must be defined as CONDA_RUN_DB_HASHSERVER_ENVIRONMENT
#
# This script is meant to be launched before seamless-dask-dynamic-wrapper,
#  potentially on a different machine or as/inside a different Slurm job.
# (For a script that is to be sourced *inside* a full deployment script, 
#  see setup-db-hashserver*.sh instead).
#
# This is a STATIC version of the script:
#   It requires all relevant Seamless variables to be pre-defined.
#   See ../multiple-delegation/ for examples:
#     COMPOSE_PROJECT_NAME is unnecessary,
#     but CONDA_RUN_DB_HASHSERVER_ENVIRONMENT must be defined.
#    Finally, the machine from which this script is launched must be defined as:
#       export SEAMLESS_DOCKER_HOST_IP=..
#
# The database file "seamless.db" is stored in DATABASE_DIR (small)
# Hashserver buffers are stored in HASHSERVER_BUFFER_DIR (can be enormous!)
#
# Syntax: ./run-db-hashserver.sh

if [ -z "$SSH_HOSTNAME" ]; then
  export SSH_HOSTNAME=$HOSTNAME
fi

set -u -e

_=$HASHSERVER_BUFFER_DIR
_=$DATABASE_DIR
_=$SEAMLESS_DATABASE_PORT
_=$SEAMLESS_HASHSERVER_PORT

mkdir -p $HASHSERVER_BUFFER_DIR
mkdir -p $DATABASE_DIR

host=0.0.0.0

set +u -e

if [ -z "$CONDA_EXE" ] || [ -z "$CONDA_SHLVL" ]; then
  echo 'conda must be installed' > /dev/stderr
  exit 1
fi

CONDA_DIR=$(python3 -c '
import os, pathlib
conda_shlvl = int(os.environ["CONDA_SHLVL"])
if conda_shlvl == 0:
    CONDA_DIR = str(pathlib.Path(os.environ["CONDA_EXE"]).parent.parent)
elif conda_shlvl == 1:
    CONDA_DIR = os.environ["CONDA_PREFIX"]
else:
    CONDA_DIR = os.environ["CONDA_PREFIX_1"]
print(CONDA_DIR)
')

source $CONDA_DIR/etc/profile.d/conda.sh

for i in $(seq ${CONDA_SHLVL}); do
    conda deactivate
done
conda activate $CONDA_RUN_DB_HASHSERVER_ENVIRONMENT

set -u -e

# Check that the correct hashserver packages are there:
python -c 'import fastapi, uvicorn'


# Check that the correct database packages are there:
python -c 'import peewee, aiohttp'

python3 -u $CONDA_PREFIX/share/seamless-cli/hashserver/hashserver.py $HASHSERVER_BUFFER_DIR --writable \
  --port $SEAMLESS_HASHSERVER_PORT --host $host \
  --layout $HASHSERVER_BUFFER_DIR_LAYOUT \
  >& $HASHSERVER_BUFFER_DIR/run-hashserver.log &
pid_hs=$!


python3 -u $CONDA_PREFIX/share/seamless-cli/database/database.py $DATABASE_DIR/seamless.db --port $SEAMLESS_DATABASE_PORT --host $host \
  >& $DATABASE_DIR/run-db.log &
pid_db=$!

trap "kill $pid_hs $pid_db" EXIT

echo 'Database and hashserver are running...' > /dev/stderr
wait