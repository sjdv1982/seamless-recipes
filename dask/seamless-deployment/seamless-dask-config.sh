export TMPDIR=/scratch/sdevries
export SEAMLESS_TOOLS_DIR=$HOME/seamless-tools
###export SEAMLESS_MINIMAL_SINGULARITY_IMAGE=docker://ubuntu:18.04

export RANDOM_PORT_START=60001
export RANDOM_PORT_END=61000

export HASHSERVER_CONDA_ENVIRONMENT=hashserver
export HASHSERVER_BUFFER_DIR=/data3/sdevries/seamless/buffers

export DATABASE_CONDA_ENVIRONMENT=seamless-database
export DATABASE_DIR=/data3/sdevries/seamless/database

# may need to be redefined/copied for each project:
export ENVIRONMENT_OUTPUT_FILE=$HOME/seamless-deployment/run-db-hashserver-env.sh
export SEAMLESS_DASK_CONDA_ENVIRONMENT=seamless-dask-development