set -u -e
echo 'Check if we are inside a Seamless conda environment'
echo 'If not, you can build one using: '
echo '  mamba env create -n seamless-dask --file https://raw.githubusercontent.com/sjdv1982/seamless/stable/conda/seamless-exact-environment.yml'
echo '  conda activate seamless-dask'
python -c 'import seamless'
mamba env update --file dask-environment-update.yaml