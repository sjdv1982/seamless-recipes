import os
from dask.distributed import Client

scheduler_address = os.environ["DASK_SCHEDULER_ADDRESS"]
client = Client(scheduler_address)

def run():
    import seamless
    return 42

job = client.submit(run)
print("Job submitted")
result = job.result()
print("Job finished")
print(result)