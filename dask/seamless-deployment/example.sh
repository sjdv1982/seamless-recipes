source seamless-dask-config.sh

# manual 
sbatch --time 72:00:00 ~/seamless-tools/scripts/run-db-hashserver-devel.sh
# wait until the first job has started...

sbatch --time 72:00:00 -c 5 ~/seamless-tools/dask-deployment/seamless-dask-wrapper ~/seamless-tools/dask-deployment/wrap-local.sh 
#or
sbatch --time 72:00:00 ~/seamless-tools/dask-deployment/seamless-dask-wrapper ~/seamless-tools/dask-deployment/wrap-slurmcluster-mini.sh 

# OR: automatic
jobid=$(sbatch --time 72:00:00 -c 5 --parsable ~/seamless-tools/scripts/run-db-hashserver-devel.sh | sed 's/,/ /g' | awk '{print $1}')
echo run-db-hashserver-devel jobid: $jobid
sbatch -d after:$jobid --time 72:00:00 ~/seamless-tools/dask-deployment/seamless-dask-wrapper ~/seamless-tools/dask-deployment/wrap-local.sh 
#or
sbatch -d after:$jobid --time 72:00:00 ~/seamless-tools/dask-deployment/seamless-dask-wrapper ~/seamless-tools/dask-deployment/wrap-slurmcluster-mini.sh 
