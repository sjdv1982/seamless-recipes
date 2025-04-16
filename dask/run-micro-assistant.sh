#!/bin/bash
#
# Run Dask micro assistant inside a conda environment

# This script is meant to be launched on a compute node that runs Seamless main scripts 
#   (Scripts that launch Seamless jobs)
# This is different from the use case where a main script is run on a desktop/laptop, and
#   the compute node executes the jobs
#   It requires all relevant Seamless variables to be defined in a config script.

#   Syntax: run-micro-assistant.sh <config script>
#   Example: run-micro-assistant.sh ./seamless-config.sh

# The conda environment can be built from dask-assistant-environment.yaml,
#  (using conda env create --file dask-assistant-environment.yaml)
#  and must be defined as CONDA_RUN_ASSISTANT_ENVIRONMENT in the config script

set -u -e

CONFIG_SCRIPT=$1

_=$CONDA_RUN_ASSISTANT_ENVIRONMENT
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
source $CONFIG_SCRIPT
conda activate $CONDA_RUN_ASSISTANT_ENVIRONMENT
source $CONFIG_SCRIPT

set -u -e

_=$HASHSERVER_BUFFER_DIR
_=$DATABASE_DIR
_=$SEAMLESS_DATABASE_PORT
_=$SEAMLESS_HASHSERVER_PORT

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