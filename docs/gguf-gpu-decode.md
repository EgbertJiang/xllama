# Experimental Xbox One S GGUF GPU inference

This local port uses upstream xllama commit `c7e71607fbd931c36ffc0167aadbae9d72c246db` with the existing llama.cpp backend API 2, AVX1 CPU target and FXC Shader Model 5.1 DXBC. The upstream Series S report is a reference, not evidence of One S performance: https://github.com/gianlucamazza/xllama/blob/666924a25179d722139ff201f214f1bc04d45cb9/docs/gguf-gpu-decode.md

## Actual One S evidence

Package 1.6.0.1063 ran on authenticated Xbox One S hardware. All 14 native backend numeric selftests passed; maximum relative error was approximately 2.61e-7. LFM 1.2B requested 99 GPU layers, placed all 17 eligible weight layers on D3D12, and recorded 6110 GPU dispatches in a 64-token run. Attention, normalization, convolution and unsupported operations still run on CPU: this is hybrid inference.

Same build, English sky prompt, 64 new tokens, context 512, 6 CPU threads, ubatch 64:

| Model                |                       CPU tok/s | GPU hybrid tok/s | Requested GPU layers |
| -------------------- | ------------------------------: | ---------------: | -------------------: |
| LFM 1.2B Q4_K_M      |                           11.88 |            17.83 |                   99 |
| LFM 350M Q4_K_M      |                           29.43 |            34.61 |                    1 |
| Qwen 3.5 0.8B Q4_K_M | 9.94 (earlier CPU build median) |            10.09 |                   99 |

These are capped short runs, not sustained throughput or quality evaluations. Qwen shows little measured benefit and stays CPU by default. Gemma E2B/E4B GPU support is unverified and stays CPU. Full private device logs are not included in this release; the summarized measurements are in `benchmark-summary.csv` in the review bundle. CSV host labels retain a legacy hardcoded Series S name.

Package 1064 additionally passed real persistent-session API checks on both LFM models: Chinese text returned and 2+2 answered with 4. LFM 1.2B recorded 2914 GPU dispatches across these short requests. Its sky explanation incorrectly attributed more absorption to red light; generated text is not a factual-quality acceptance. The underlying private device logs are not included in this release.

## Configuration

In the existing LocalState `manifest.json`, copy a complete model entry and add `"gpu_layers": 99` (or 1 for LFM 350M). Missing/zero selects CPU; integer values 0 through 999 are accepted. The existing GUI and chat/embedding API session paths share this catalogue field. Restart the app after changing it so an existing resident session is recreated. `bench_gpu_layers.txt` controls only headless benchmarks. ORT EP settings do not control this GGUF backend.

Use Game classification in Dev Home after each package update. Keep the known-working CPU package available. Unsupported adapters and kernels may fall back to CPU; layer requests alone are not proof of GPU work. Build with the existing AVX target; `scripts/compile-ggml-d3d12-fxc.sh` reproduces the seven DXBC shader headers. Windows MSBuild and Linux CLI execution of this port have not been validated.

## One S larger-context check

At the user's request, the LFM 1.2B local catalogue override was increased
from 512 to 8192 tokens. Package 1066 on the same One S loaded that session
with native D3D12 hybrid placement and returned a short arithmetic answer.
A 4260-token input recovered a six-digit code from its opening in 140.57 s.
A near-limit 7620-token input recovered the same opening code in 281.95 s,
returning 2 completion tokens. These wall times include prefill and generation;
they are not decode throughput. The synthetic retrieval check is not a broad
long-context quality evaluation. The underlying private device logs are not included in this release. Other model
context overrides were retained. The program's 8192-token catalogue clamp was
not increased.
