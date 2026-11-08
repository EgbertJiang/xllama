# xllama on Xbox One S

[中文](README.zh-CN.md)

This is an experimental patch set for running [xllama](https://github.com/gianlucamazza/xllama) on an Xbox One S in Developer Mode. It adds a Direct3D 12 backend for supported GGUF operations, a console chat interface, and a browser chat page served on the local network.

GPU inference is hybrid: supported weight matrix operations run on the GPU, while attention, normalization, and other operations run on the CPU.

## Results on Xbox One S

These are short, single-run comparisons using the same build, an English prompt, 64 generated tokens, a 512-token context, and six CPU threads.

| Model | Quantization | CPU | CPU + GPU | Requested GPU layers |
| --- | --- | ---: | ---: | ---: |
| LFM2.5 1.2B Instruct | Q4_K_M | 11.88 tokens/s | 17.83 tokens/s | 99 |
| LFM2.5 350M | Q4_K_M | 29.43 tokens/s | 34.61 tokens/s | 1 |

The GPU backend passed 14 numerical checks. The 1.2B run also recorded GPU dispatches. These measurements do not establish sustained throughput or answer quality.

With the 1.2B model configured for an 8,192-token context, a synthetic 7,620-token input recovered a six-digit code placed at the beginning. The request took 281.95 seconds, including prompt processing and generation. This is one retrieval check, not a general long-context evaluation.

Gemma 4 E4B IQ2_M ran on the One S CPU at 1.71 tokens/s in one 32-token test. GPU inference for that model has not been verified. Series X, long-term stability, physical mouse input, and Chinese IME composition have not been independently tested.

## Source and submodule

This branch is based on xllama commit `a13d237f547577735d2e5c4d60689dfa27135ce9`. It contains the One S changes to the parent repository. The llama.cpp submodule is pinned to `b29c606e28a01b1bc8c1351026a0fa6e616bf6c4`; the required submodule changes are kept in `patches/xbox-one-s/llama-cpp.patch` rather than a separate fork.

After initializing the submodule, check and apply that patch inside `llama.cpp`. Both the parent changes and the submodule patch were checked against their respective base commits. `patches/xbox-one-s/benchmark-summary.csv` records the short comparisons above.

## Build status

The console package used for testing was built with an experimental Linux cross-compilation toolchain, the Windows SDK, runtime libraries, and a local test certificate. This branch does not yet provide a one-command build or a verified clean-environment setup. Windows MSBuild has not been tested. See `docs/gguf-gpu-decode.md` for the backend and test details.

This branch adds no model weights, MSIX, private signing keys, device logs, or account credentials. The browser and API use unauthenticated LAN HTTP; the Xbox application must remain in the foreground while serving requests.

## Attribution and licenses

This work builds on [xllama](https://github.com/gianlucamazza/xllama), which is distributed under the MIT License. A fork must retain the upstream copyright notice and license. llama.cpp, model weights, runtime libraries, and other dependencies have their own licenses and distribution terms.
