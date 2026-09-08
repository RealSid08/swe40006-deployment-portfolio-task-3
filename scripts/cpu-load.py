#!/usr/bin/env python3
"""Short, bounded CPU load for the CloudWatch alarm demonstration.

Run through SSM on both backend instances. This does not simulate alarm state.
The operator temporarily enables T3 unlimited credits and pauses automatic
scaling actions, then restores both settings after the test.
"""

import argparse
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--seconds", type=int, default=240)
args = parser.parse_args()
if not 60 <= args.seconds <= 300:
    parser.error("duration must be between 60 and 300 seconds")

workers = []
try:
    print("CPU test started:", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), flush=True)
    for _ in range(2):
        workers.append(subprocess.Popen(["yes"], stdout=subprocess.DEVNULL))
    time.sleep(args.seconds)
finally:
    for worker in workers:
        worker.terminate()
    for worker in workers:
        worker.wait(timeout=5)
    print("CPU test finished:", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), flush=True)
