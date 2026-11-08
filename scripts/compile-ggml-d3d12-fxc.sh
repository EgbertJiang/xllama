#!/usr/bin/env bash
# Rebuild the seven Xbox One baseline ggml D3D12 shaders using existing FXC.
# Input HLSL must already use scalar signed-byte dot4 (no SM6.4 intrinsic).
# Run inside the existing Linux/amd64 build container; no tools are installed.
# Example after placing this file under source/scripts:
# FXC='/cache/sdk/Windows Kits/10/bin/10.0.22621.0/x64/fxc.exe' \
#   bash scripts/compile-ggml-d3d12-fxc.sh
# For another tree: XLLAMA_SHADER_ROOT=/absolute/source/root ... same command.
set -euo pipefail
ROOT="${XLLAMA_SHADER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
: "${FXC:?Set FXC to the existing Windows SDK x64 fxc.exe}"
FXC_RUNNER="${FXC_RUNNER:-wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
# Per-process override only; does not change Wine registry or prefix configuration.
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-d3dcompiler_47=n}"
OUT="$ROOT/shaders/generated"
mkdir -p "$OUT"
compile_one() {
 local source="$1" stem="$2" symbol="$3"
 shift 3
 "$FXC_RUNNER" "$FXC" /nologo /Od /T cs_5_1 /E CSMain "$@" \
  /Fo "Z:$OUT/$stem.bin" "Z:$ROOT/shaders/$source"
 python3 - "$OUT/$stem.bin" "$OUT/${stem}_dxil.h" "$symbol" "$source" <<'PY'
import hashlib,json,struct,sys
from pathlib import Path
binary,header=map(Path,sys.argv[1:3]);symbol,source=sys.argv[3:5];data=binary.read_bytes()
assert data[:4]==b'DXBC', 'Expected real DXBC bytecode'
version=None
for i in range(struct.unpack_from('<I',data,28)[0]):
 offset=struct.unpack_from('<I',data,32+4*i)[0]
 if data[offset:offset+4] in [b'SHEX',b'SHDR']:
  version=struct.unpack_from('<I',data,offset+8)[0]
assert version==0x50051, f'Expected cs5.1, got {version!r}'
lines=['// GENERATED FXC /T cs_5_1 /E CSMain /Od. Actual bytecode is DXBC.',
       '// Legacy *_dxil filename/symbol retained solely for upstream C++ source compatibility.',
       '#pragma once','#include <cstddef>','#include <cstdint>','// clang-format off',
       f'static const uint8_t {symbol}[] = {{']
for i in range(0,len(data),12):
 lines.append('    '+', '.join(f'0x{x:02x}' for x in data[i:i+12])+',')
lines+=['};',f'static const size_t {symbol}Size = {len(data)};','// clang-format on']
header.write_text('\n'.join(lines)+'\n')
record={'source':source,'binary':binary.name,'header':header.name,'symbol':symbol,
        'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
        'container':'DXBC','profile':'cs_5_1','optimization':'/Od'}
header.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
print(f'{header.name}: {len(data)} bytes; sha256={record["sha256"]}')
PY
}
for type in q4_0 q4_k q6_k; do
 case "$type" in q4_0) cap=Q40;; q4_k) cap=Q4K;; q6_k) cap=Q6K;; esac
 for width in 64 128; do
  compile_one "ggml_d3d12_mmv_${type}.hlsl" "ggml_d3d12_mmv_${type}_t${width}" \
   "kGgmlD3d12Mmv${cap}T${width}Dxil" /D "NUM_THREADS=$width"
 done
done
compile_one ggml_d3d12_get_rows_q6_k.hlsl ggml_d3d12_get_rows_q6_k kGgmlD3d12GetRowsQ6KDxil
