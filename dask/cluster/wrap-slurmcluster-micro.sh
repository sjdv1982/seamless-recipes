#!/bin/bash
# a wrapper around slurmcluster-micro.py to be used with seamless-dask-dynamic-wrapper and the dask-micro-assistant

if [ -z "$PS1" ]; then
       interactive_flag=""
else
       interactive_flag="-i"
fi

set -u -e

currdir=`python3 -c 'import os,sys;print(os.path.dirname(os.path.realpath(sys.argv[1])))' $0`

# Does not work (asyncio trouble)
#ipython3 $interactive_flag $currdir/slurmcluster-micro.py -- --host $SEAMLESS_ASSISTANT_HOST --port $DASK_SCHEDULER_PORT

python3 -u $interactive_flag $currdir/slurmcluster-micro.py --host $SEAMLESS_ASSISTANT_HOST --port $DASK_SCHEDULER_PORT