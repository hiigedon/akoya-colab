"""
Pearlhash Miner on Modal.com — A100-80GB
Deploy: modal deploy pearlhash_modal.py
Run:    modal run pearlhash_modal.py
"""

import modal

app = modal.App("pearlhash-miner")

WALLET = "prl1ph0yxdqm26pm0370hgh659kgfprh9l4wz4pf27et43x3zwdat60mqsn6p4w"
POOL_HOST = "84.32.220.219:9000"
WORKER = "modal-a100"

pearlhash_image = (
    modal.Image.from_registry(
        "nvidia/cuda:12.4.0-runtime-ubuntu22.04",
        add_python="3.11",
    )
    .apt_install("curl", "libgomp1")
    .run_commands(
        "curl https://pearlhash.xyz/downloads/pearl-miner-v8 -o /opt/pearl-miner && "
        "chmod +x /opt/pearl-miner"
    )
)


@app.function(
    gpu="A100-80GB",
    image=pearlhash_image,
    timeout=86400,
    scaledown_window=300,
)
def mine():
    import subprocess
    import os

    print(f"[Modal] Pearlhash Miner on A100-80GB")
    print(f"[Modal] Pool: {POOL_HOST}")
    print(f"[Modal] Wallet: {WALLET}")
    print(f"[Modal] Worker: {WORKER}")
    print()

    proc = subprocess.Popen(
        ["/opt/pearl-miner", "--host", POOL_HOST, "--user", WALLET, "--worker", WORKER],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    print(f"[Modal] Miner PID: {proc.pid}")

    for line in iter(proc.stdout.readline, b""):
        print(line.decode().strip(), flush=True)

    return proc.wait()


@app.local_entrypoint()
def main():
    mine.remote()
