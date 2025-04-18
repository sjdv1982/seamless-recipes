# Dask deployment

There are five methods to start up a Seamless Dask deployment:

- Local
- Remote with direct connection
- Remote over SSH
- Slurm with direct connection
- Slurm over SSH

## Storage directories

For the first three methods, the storage directories will be the Seamless default:

- remote database in $HOME/seamless/database (small)
- remote buffer storage in $HOME/seamless/buffers (potentially huge)

This is currently hardcoded in setup-db-hashserver-devel.sh.

For the two Slurm methods, the default directories are the above, but you can define
$DATABASE_DIR and $HASHSERVER_BUFFER_DIR.

## Local method

- Activate the Seamless Dask conda environment
- `source seamless-fill-environment-variables`, then launch local.py and keep it alive. Note the Dask scheduler address. You can get the same address every time
by adding `--port XXXX`.
- In a different terminal, do `export DASK_SCHEDULER_ADDRESS=...`  and then `seamless-delegate X-dask-assistantY`, where X is "micro" or "mini" and Y can be empty or "-devel"

## Remote method with direct connection

This requires that the remote IP address is directly reachable from your machine.
You must define a port range, and all ports within that range must be accessible.

- Log in (or launch a batch shell script) on a remote machine.
- There, activate the Seamless Dask conda environment
- Run `./local.sh $RANDOM_PORT_START $RANDOM_PORT_END`, specifying a random port range for the hashserver, the database, and the Dask scheduler. You may add a hostname too. Keep this script alive. (See below for alternatives.)
- Variables will be printed out. Copy the variable section for direct connection.
- In a new local terminal, paste the variable section.
- In that terminal, start `seamless-delegate-remote mini-dask-assistant` (or `mini-dask-assistant-devel`)
- Instead of `local.sh`, you can also use a script that dynamically launches jobs on an HPC cluster. There is currently `wrap-slurmcluster-micro.sh`, `wrap-slurmcluster-mini.sh`, `wrap-slurmcluster-minifront.sh`, wrapping `slurmcluster-micro.py`,  `slurmcluster-mini.py`
and `slurmcluster-minifront.py` (there is also `slurmcluster-minifront-singularity.py`).
- Finally, paste the variable section into the shell where you will be using Seamless.
(TODO: describe static configuration where you pre-choose the ports)

## Remote method with SSH tunneling

This requires that the remote IP address can be reached via SSH without login.
The remote ports are tunneled to the default local Seamless ports. Therefore,
`seamless-delegate-stop` must be called to stop any existing local delegation.

- Log in (or launch a batch shell script) on a remote machine.
- There, activate the Seamless Dask conda environment
- Run `./one-node.sh $RANDOM_PORT_START $RANDOM_PORT_END 0.0.0.0`, specifying a random port range for the hashserver, the database, and the Dask scheduler, and a hostname 0.0.0.0 that listens on all IP addresses. You may try to omit 0.0.0.0 or give a different hostname.
Keep this script alive.
(There may be alternatives to `one-node.sh` that dynamically launch new jobs on the cluster).
- Variables will be printed out. Copy the variable section for SSH connection.
  You may need to change SEAMLESS_SSH_DATABASE_HOST/SEAMLESS_SSH_HASHSERVER_HOST
  if it is different from the entry in your `.ssh/config`.
- In a new local terminal, paste the variable section.
- In that terminal, start `seamless-delegate-ssh mini-dask-assistant` (or `mini-dask-assistant-devel`). Unlike the other `seamless-delegate*` scripts, the terminal will block hile `seamless-delegate-ssh` is active.  

## Slurm

The instructions below are terse. See `scripts/run-db-hashserver-devel.sh` for more details about the meaning of each variable.

- You must build and define `$HASHSERVER_CONDA_ENVIRONMENT` and `$DATABASE_CONDA_ENVIRONMENT`.

- Define at least `$RANDOM_PORT_START` and `$RANDOM_PORT_END`.

- Activate conda.

- Launch one of `run-db-hashserver*.sh` as a long-running Slurm job, e.g. using
`sbatch --time 72:00:00`. Other Slurm parameters are in the script.
Example: `sbatch --time 72:00:00 ~/seamless-tools/scripts/run-db-hashserver-devel.sh`

- Once the script has started, it will write a file `$ENVIRONMENT_OUTPUT_FILE`. Wait until then.

- On a HPC node, you will probably want to re-define `TMPDIR` as a folder under `/scratch`, so that intermediate files are stored on a local hard disk and not on the network. This is especially important for `bin/seamless` and bash transformers.

Now comes the project-specific part:

- Build your project-specific Seamless+Dask conda environment, for example with the help of `dask-deployment/build-environment*.sh`, and then adding specific libraries. Specify its name in `SEAMLESS_DASK_CONDA_ENVIRONMENT`.

- You might want to clone and redefine `ENVIRONMENT_OUTPUT_FILE`, because the next Slurm command will modify the file.

- Submit `seamless-dask-dynamic-wrapper <wrap-script>` under `sbatch`. This will launch a Dask scheduler and workers inside the Seamless+Dask environment. For now, there are
two wrap scripts: `wrap-local.sh` for deployment of workers on a single node (like the first three methods) and `wrap-slurmcluster-XXX.sh`. The latter uses SLURMCluster from the dask-jobqueue project in order to launch new Dask workers dynamically using Slurm.
`wrap-slurmcluster-XXX.sh` comes in three versions:
  - `wrap-slurmcluster-micro.sh` which launches `slurmcluster-micro.py` for use with the dask-micro-assistant.
  -`wrap-slurmcluster-mini.sh` which launches `slurmcluster-mini.py` for use with the dask-mini-assistant.
  - `wrap-slurmcluster-minifront.sh`which launches `slurmcluster-minifront.py` for use with the dask-minifront-assistant. The minifront script launches a mini assistant in a parallel process and forwards all job requests to it, allowing a separation of the Dask process and the Seamless assistant process.
  (For the truly paranoid, there is also `slurmcluster-minifront-singularity.py`, which wraps the mini assistant in a minimal (non-isolated) Singularity image. This in fact removes the mini assistant PID from direct Slurm control.)
If you use `wrap-slurmcluster-XXX.sh`, you may want to copy and modify `slurmcluster-XXX.py` to control Dask resources (number of jobs, memory, etc.)

Example: `sbatch --time 72:00:00 ~/seamless-tools/dask-deployment/seamless-dask-dynamic-wrapper ~/seamless-tools/dask-deployment/wrap-slurmcluster-mini.sh`

You can also launch `seamless-dask-dynamic-wrapper <wrap-script>` on a cluster front-end.
In that case, an interactive Python session (not IPython, unfortunately; IPython gives trouble with asyncio) is opened, where you can manipulate the `cluster` object.

- Copy the contents of `$ENVIRONMENT_OUTPUT_FILE`.

### Slurm with direct connection

This requires that the remote IP address is directly reachable from your machine.

- In a new local terminal, paste the contents of `$ENVIRONMENT_OUTPUT_FILE`.
- In that terminal, start `seamless-delegate-remote mini-dask-assistant` (or `mini-dask-assistant-devel`)
- In any local terminal, paste the variable section.
  Then, start `seamless-bash`, or import seamless directly from conda, or use
  `/bin/seamless`.

### Slurm with SSH tunneling

- In a new local terminal, paste the contents of `$ENVIRONMENT_OUTPUT_FILE`.
- In that terminal, start `seamless-delegate-ssh mini-dask-assistant` (or `mini-dask-assistant-devel`). Unlike the other `seamless-delegate*` scripts, the terminal will block while `seamless-delegate-ssh` is active.  
- In another local terminal, start `seamless-bash`, or import seamless directly from conda, or use `/bin/seamless`. Pasting the variable section is not necessary.
