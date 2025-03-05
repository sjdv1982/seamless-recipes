conda activate run-db-hashserver
source ./example-config.sh
sbatch --time 72:00:00 run-db-hashserver-dynamic.sh