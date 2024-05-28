source seamless-dask-config.sh

## # manual 
## sbatch --time 72:00:00 ~/seamless-recipes/run-db-hashserver/run-db-hashserver.sh
## # wait until the first job has started...
##
## sbatch --time 72:00:00 -c 5 ~/seamless-recipes/dask/seamless-dask-wrapper ~/seamless-recipes/dask/wrap-local.sh 
## #or
## sbatch --time 72:00:00 ~/seamless-recipes/dask/seamless-dask-wrapper ~/seamless-recipes/dask/cluster/wrap-slurmcluster-mini.sh 

# OR: automatic
jobid=$(sbatch --time 72:00:00 -c 5 --parsable ~/seamless-recipes/run-db-hashserver/run-db-hashserver.sh | sed 's/,/ /g' | awk '{print $1}')
echo run-db-hashserver jobid: $jobid
## sbatch -d after:$jobid --time 72:00:00 ~/seamless-recipes/dask/seamless-dask-wrapper ~/seamless-recipes/dask/wrap-local.sh 
#or
sbatch -d after:$jobid --time 72:00:00 ~/seamless-recipes/dask/seamless-dask-wrapper ~/seamless-recipes/dask/cluster/wrap-slurmcluster-mini.sh 
