export CONDA_RUN_DB_HASHSERVER_ENVIRONMENT=run-db-hashserver

export RANDOM_PORT_START=60001
export RANDOM_PORT_END=61000

export HASHSERVER_BUFFER_DIR=/home/user/seamless/buffers
export HASHSERVER_BUFFER_DIR_LAYOUT=flat  # can be "flat" or "prefix"
export DATABASE_DIR=/home/user/seamless/database

# may need to be redefined/copied for each project:
export ENVIRONMENT_OUTPUT_FILE=/home/user/seamless-deployment-env.sh
