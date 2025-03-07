#!/bin/bash
# Run a database and hashserver inside a Seamless development conda environment with extra packages
#
# This script contains Slurm directives, but can also be launched independently
#
# This script is meant to be launched before seamless-dask-dynamic-wrapper,
#  potentially on a different machine or as/inside a different Slurm job.
# (For a script that is to be sourced *inside* a full deployment script, 
#  see setup-db-hashserver*.sh instead).
#
# Note: this is a DEVELOPMENT version, requiring SEAMLESS_TOOLS_DIR to be defined
#
# It requires conda environments for the hashserver and the database to have been setup.
# The conda environment names are in HASHSERVER_CONDA_ENVIRONMENT and DATABASE_CONDA_ENVIRONMENT
# If these variables do not exist, their names are "hashserver" and "seamless-database".
# Make sure that these environments exist!
# To see the required packages:
# - See $SEAMLESS_TOOLS_DIR/seamless-cli/hashserver/environment.yml for hashserver
# - See $SEAMLESS_TOOLS_DIR/seamless-cli/database/database.Dockerfile for seamless-database
#
# It also requires a port range to be available on the node 
# towards the exterior, e.g 60001-61000
# This port range must be defined as the variables 
# RANDOM_PORT_START and RANDOM_PORT_END
#
# The database file "seamless.db" is stored in DATABASE_DIR (small)
# Hashserver buffers are stored in HASHSERVER_BUFFER_DIR (can be enormous!)
#
#
# Syntax: ./run-db-hashserver.sh
# Once it has started, it will generate a file $ENVIRONMENT_OUTPUT_FILE
#  (by default, ~/.seamless/seamless-env.sh)
# containing the network configuration of the Seamless hashserver and database.
#
# This file can then be included by:
# - Assistant scripts, e.g. a Slurm-based Seamless+Dask deployment script
# - Seamless clients that don't need an assistant (level 3 delegation or lower)

#SBATCH --job-name=run-db-hashserver
#SBATCH -o run-db-hashserver.out
#SBATCH -e run-db-hashserver.err

# 3 cores: can probably do with less
#SBATCH -c 3

# 500 MB of memory, should be plenty (?)
#SBATCH --mem=500MB

# If possible, run indefinitely
#SBATCH --time=0

set -u -e


x=$RANDOM_PORT_START
x=$RANDOM_PORT_END
SEAMLESS_TOOLS_DIR_OLD=$SEAMLESS_TOOLS_DIR

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

CONDA_EXE_ORIG=$CONDA_EXE

source $CONDA_DIR/etc/profile.d/conda.sh

for i in $(seq ${CONDA_SHLVL}); do
    conda deactivate
done
export CONDA_EXE=$CONDA_EXE_ORIG

conda activate

source $CONDA_DIR/etc/profile.d/conda.sh

if [ -z "$HASHSERVER_CONDA_ENVIRONMENT" ]; then
    HASHSERVER_CONDA_ENVIRONMENT='hashserver'
    echo "HASHSERVER_CONDA_ENVIRONMENT not defined. Using default: hashserver" > /dev/stderr
fi

if [ -z "$HASHSERVER_BUFFER_DIR" ]; then
    HASHSERVER_BUFFER_DIR=$HOME/.seamless/buffers
    echo "HASHSERVER_BUFFER_DIR not defined. Using default: " $HASHSERVER_BUFFER_DIR > /dev/stderr
fi
mkdir -p $HASHSERVER_BUFFER_DIR

if [ -z "$DATABASE_CONDA_ENVIRONMENT" ]; then
    DATABASE_CONDA_ENVIRONMENT='seamless-database'
    echo "DATABASE_CONDA_ENVIRONMENT not defined. Using default: seamless-database" > /dev/stderr
fi

if [ -z "$DATABASE_DIR" ]; then
    DATABASE_DIR=$HOME/.seamless/database
    echo "DATABASE_DIR not defined. Using default: " $DATABASE_DIR > /dev/stderr
fi
mkdir -p $DATABASE_DIR


if [ -z "$ENVIRONMENT_OUTPUT_FILE" ]; then
    ENVIRONMENT_OUTPUT_FILE=$HOME/run-db-hashserver-env.sh
    echo "ENVIRONMENT_OUTPUT_FILE not defined. Using default: " $ENVIRONMENT_OUTPUT_FILE > /dev/stderr
fi

set -u -e

function random_port {
    echo $(python -c '
import sys
start, end = [int(v) for v in sys.argv[1:]]
import random
print(random.randint(start, end))
' $RANDOM_PORT_START $RANDOM_PORT_END)
}

export SEAMLESS_DATABASE_PORT=$(random_port)
export SEAMLESS_HASHSERVER_PORT=$(random_port)

for i in $(seq 10); do
    conda deactivate
done
export CONDA_EXE=$CONDA_EXE_ORIG
conda activate

set -u -e

conda activate $HASHSERVER_CONDA_ENVIRONMENT

# Check that the correct packages are there:
python -c 'import fastapi, uvicorn'

conda deactivate

conda activate $DATABASE_CONDA_ENVIRONMENT

# Check that the correct packages are there:
python -c 'import peewee, aiohttp'

conda deactivate

conda activate $HASHSERVER_CONDA_ENVIRONMENT
SEAMLESS_TOOLS_DIR=$SEAMLESS_TOOLS_DIR_OLD
cd $SEAMLESS_TOOLS_DIR/seamless-cli/hashserver
python3 -u hashserver.py $HASHSERVER_BUFFER_DIR --writable \
  --port $SEAMLESS_HASHSERVER_PORT --host $host \
  --layout $HASHSERVER_BUFFER_DIR_LAYOUT \
  >& $HASHSERVER_BUFFER_DIR/run-hashserver.log &
pid_hs=$!
conda deactivate


conda activate $DATABASE_CONDA_ENVIRONMENT
SEAMLESS_TOOLS_DIR=$SEAMLESS_TOOLS_DIR_OLD
cd $SEAMLESS_TOOLS_DIR/tools
python3 -u database.py $DATABASE_DIR/seamless.db --port $SEAMLESS_DATABASE_PORT --host $host \
  >& $DATABASE_DIR/run-db.log &
pid_db=$!
conda deactivate


ip=$(hostname -I | awk '{print $1}')

cat /dev/null > $ENVIRONMENT_OUTPUT_FILE 
echo ' # This file has been auto-generated by run-db-hashserver-devel.sh' >> $ENVIRONMENT_OUTPUT_FILE 
echo '' >> $ENVIRONMENT_OUTPUT_FILE 
echo ' # For direct connection:' >> $ENVIRONMENT_OUTPUT_FILE 
echo ' #########################################################################' >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_DATABASE_IP='$ip >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_DATABASE_PORT='$SEAMLESS_DATABASE_PORT >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_READ_BUFFER_SERVERS='http://$ip:$SEAMLESS_HASHSERVER_PORT >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_WRITE_BUFFER_SERVER='http://$ip:$SEAMLESS_HASHSERVER_PORT >> $ENVIRONMENT_OUTPUT_FILE 
echo ' #########################################################################' >> $ENVIRONMENT_OUTPUT_FILE 
echo >> $ENVIRONMENT_OUTPUT_FILE 
echo ' # For seamless-delegate-ssh:' >> $ENVIRONMENT_OUTPUT_FILE 
echo ' #########################################################################' >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_SSH_HASHSERVER_HOST='$HOSTNAME >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_SSH_HASHSERVER_PORT='$SEAMLESS_HASHSERVER_PORT >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_SSH_DATABASE_HOST='$HOSTNAME >> $ENVIRONMENT_OUTPUT_FILE 
echo ' export SEAMLESS_SSH_DATABASE_PORT='$SEAMLESS_DATABASE_PORT >> $ENVIRONMENT_OUTPUT_FILE 
echo ' #########################################################################' >> $ENVIRONMENT_OUTPUT_FILE 
echo '' >> $ENVIRONMENT_OUTPUT_FILE 

trap "rm -f $ENVIRONMENT_OUTPUT_FILE; kill $pid_hs $pid_db" EXIT

echo 'Database and hashserver are running...' > /dev/stderr
wait