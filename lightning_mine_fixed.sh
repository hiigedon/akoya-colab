#!/bin/bash
set -e
WALLET="prl1pz058x4ummgcmeh9pu8fnzqx989hfqftmxlg3prl3h9mwndzktgaqyv2gm8"
WORKER="lightning-gpu"
MINER_DIR="$HOME/akoya-miner"

echo "🐚 Akoya Pearl Miner - Lightning.ai (Fixed)"
echo "============================================="

echo "[1/4] Checking GPU..."
if ! command -v nvidia-smi &>/dev/null; then
    echo "❌ No GPU detected!"; exit 1
fi
GPU_INFO=$(nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader)
echo "  GPU: $GPU_INFO"
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
MAJOR=${CC%%.*}; MINOR=${CC##*.}
if [ "$MAJOR" -lt 8 ]; then echo "❌ GPU compute $CC < 8.0"; exit 1; fi
echo "  ✅ Compute $CC supported"

echo "[2/4] Installing tools..."
sudo apt-get update -qq && sudo apt-get install -y -qq skopeo umoci >/dev/null 2>&1 || \
apt-get update -qq 2>/dev/null && apt-get install -y -qq skopeo umoci >/dev/null 2>&1
echo "  ✅ Tools ready"

echo "[3/4] Downloading Akoya miner..."
rm -rf "$MINER_DIR" /tmp/akoya-oci /tmp/akoya-bundle
skopeo copy docker://registry.akoyapool.com/akoya-miner:latest oci:/tmp/akoya-oci:latest
umoci unpack --rootless --image /tmp/akoya-oci:latest /tmp/akoya-bundle
mkdir -p "$MINER_DIR"
cp -r /tmp/akoya-bundle/rootfs/app/* "$MINER_DIR/"
chmod +x "$MINER_DIR/akoya-miner"
echo "  ✅ Miner downloaded"

echo "[4/4] Setting up GPU kernel..."
LIB_DIR="$MINER_DIR/lib"
TARGET="$LIB_DIR/libpearl_gemm_capi.so"
if [ "$MAJOR" -eq 12 ]; then SRC="blackwell"
elif [ "$MAJOR" -eq 9 ]; then SRC="h100"
elif [ "$MAJOR" -eq 8 ] && [ "$MINOR" -eq 9 ]; then SRC="ada"
elif [ "$MAJOR" -eq 8 ]; then SRC="ampere"
else SRC="portable"; fi
rm -f "$TARGET"
ln -s "$LIB_DIR/libpearl_gemm_capi_${SRC}.so" "$TARGET"
echo "  ✅ Kernel: $SRC"

echo ""
echo "🚀 Starting miner..."
echo "   Wallet: ${WALLET:0:15}...${WALLET: -8}"
echo "   Worker: $WORKER"
echo "============================================"

export AKOYA_POOL_WALLET="$WALLET"
export AKOYA_POOL_WORKER="$WORKER"
export AKOYA_POOL_HOST="pool-v2.akoyapool.com"
export AKOYA_POOL_PORT="443"
export AKOYA_POOL_USE_TLS="1"
export AKOYA_GPU_INDICES="all"
export AKOYA_METRICS_PORT="9100"
export AKOYA_PEARL_GEMM_LIB="$MINER_DIR/lib/libpearl_gemm_capi.so"
export AKOYA_PEARL_MINING_LIB="$MINER_DIR/lib/libpearl_mining_capi.so"
export LD_LIBRARY_PATH="$MINER_DIR/lib/cuda:$MINER_DIR/lib:$LD_LIBRARY_PATH"
mkdir -p "$HOME/.akoya-miner"

exec "$MINER_DIR/akoya-miner" mine-blocks
