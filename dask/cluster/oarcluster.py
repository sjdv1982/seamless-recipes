"""
Launches a Dask scheduler to be used with Seamless by setting up an OARCluster.
For use with the dask-micro-assistant.

It is recommended to use this with seamless-dask-wrapper

See local.py for more details about starting Dask in a Seamless-compatible manner.

All Dask jobs will be started inside an environment SEAMLESS_DASK_CONDA_ENVIRONMENT.
dask-jobqueue must have been installed

Worker ports will be opened between RANDOM_PORT_START and RANDOM_PORT_END
"""

import dask
import sys
import os
import argparse
from urllib.parse import urlparse

# Check that delegation works
os.environ["SEAMLESS_DATABASE_IP"]
os.environ["SEAMLESS_DATABASE_PORT"]
os.environ["SEAMLESS_READ_BUFFER_SERVERS"]
os.environ["SEAMLESS_WRITE_BUFFER_SERVER"]

# Check that port range is defined
os.environ["RANDOM_PORT_START"]
os.environ["RANDOM_PORT_END"]

# Check that conda works
os.environ["CONDA_PREFIX"]
os.environ["SEAMLESS_DASK_CONDA_ENVIRONMENT"]

parser = argparse.ArgumentParser()
parser.add_argument("--host", default="0.0.0.0", required=False)
parser.add_argument("--port", default=0, type=int, required=False)
args = parser.parse_args()

import logging
logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)



import tempfile
print("Temp dir", tempfile.gettempdir())
if "TMPDIR" not in os.environ:
    os.environ["TMPDIR"] = tempfile.gettempdir()

from dask_jobqueue import OARCluster
from dask_jobqueue.oar import OARJob

scheduler_kwargs={"host":args.host}
if args.port > 0:
    scheduler_kwargs["port"] = args.port

conda_shlvl = int(os.environ["CONDA_SHLVL"])
if conda_shlvl == 1:
    CONDA_PREFIX = os.environ["CONDA_PREFIX"]
else:
    CONDA_PREFIX = os.environ["CONDA_PREFIX_1"]

TMPDIR=os.environ.get("DASK_WORKER_TMPDIR", os.environ.get("TMPDIR", "/tmp"))
exported_vars = [
    "SEAMLESS_DASK_CONDA_ENVIRONMENT",
    "SEAMLESS_DATABASE_IP",
    "SEAMLESS_DATABASE_PORT",
    "SEAMLESS_READ_BUFFER_SERVERS",
    "SEAMLESS_WRITE_BUFFER_SERVER"
]
exported_var_data = []
for var in exported_vars:
    exported_var_data.append("export {}={}".format(var, os.environ[var]))


ncores=40  # how many CPUs to reserve
ntasks=20   # how many Dask tasks to run simultaneously
memory="96 GB"
walltime="01:00:00"
lifetime="50m"
lifetime_stagger="4m"

class MyOARJob(OARJob):
    worker_process_threads=ntasks

class MyOARCluster(OARCluster):
    job_cls = MyOARJob

dask.config.set({"distributed.worker.resources.ncores": ncores})
dask.config.set({"distributed.scheduler.unknown-task-duration": "1m"})
dask.config.set({"distributed.scheduler.target-duration": "10m"})
cluster = MyOARCluster(
    queue='abaca',

    walltime=walltime,

    # processes should be 1, otherwise you get trouble
    processes=1, 
    
    # The scheduler will send this many tasks to each job
    cores=ncores,
    memory=memory,
    memory_per_core_property_name="memcore",
    python="python",

    #job_cpu=ncores+2,

    job_extra_directives=[
        '-p grappe',
        ' --project=capsid'
    ],
    
    job_script_prologue=[
        "set -u -e",
        "source {}/etc/profile.d/conda.sh".format(CONDA_PREFIX),        
        "conda info --envs",    
        "conda activate {}".format(os.environ["SEAMLESS_DASK_CONDA_ENVIRONMENT"])
    ] 
    + exported_var_data +
    [
        "export DASK_DISTRIBUTED__WORKER__MULTIPROCESSING_METHOD=fork",
        "export DASK_DISTRIBUTED__WORKER__DAEMON=False",
        f"export TMPDIR={TMPDIR}"
    ],

    worker_extra_args=[
        "--worker-port={}:{}".format(
            os.environ["RANDOM_PORT_START"],
            os.environ["RANDOM_PORT_END"]
        ),
        "--nanny-port={}:{}".format(
            os.environ["RANDOM_PORT_START"],
            os.environ["RANDOM_PORT_END"]
        ),
        f"--resources \"ncores={ncores}\"",
        "--lifetime", lifetime, 
        "--lifetime-stagger", lifetime_stagger,
    ],
    scheduler_options=scheduler_kwargs,
)

cluster.adapt(minimum_jobs=1, maximum_jobs=16)

print(cluster.job_script())

assert args.port == urlparse(cluster.scheduler_address).port, cluster.scheduler_address

print("Dask scheduler address:")
print(cluster.scheduler_address)
sys.stdout.flush()

def is_interactive():
    if sys.flags.interactive:
        return True
    try:
        from IPython import get_ipython
        return (get_ipython() is not None)
    except ImportError:
        return False

if not is_interactive():
    print("Press Ctrl+C to stop")    
    import time
    while 1:
        time.sleep(10)
        sys.stdout.flush()