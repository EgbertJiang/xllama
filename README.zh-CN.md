# 在 Xbox One S 上运行 xllama

[English](README.md)

这是一组针对 [xllama](https://github.com/gianlucamazza/xllama) 的实验性补丁，用于在 Xbox One S 开发者模式下运行模型。补丁为受支持的 GGUF 运算加入 Direct3D 12 后端，并提供主机对话界面和局域网聊天网页。

推理采用 CPU 与 GPU 混合方式：受支持的权重矩阵运算由 GPU 执行，注意力、归一化及其他运算仍由 CPU 执行。

## Xbox One S 实测

以下数据来自同一构建版本下的短文本单次对比，使用英文提示、生成 64 个 token、512 token 上下文和 6 个 CPU 线程。

| 模型 | 量化 | CPU | CPU + GPU | 请求卸载的 GPU 层数 |
| --- | --- | ---: | ---: | ---: |
| LFM2.5 1.2B Instruct | Q4_K_M | 11.88 token/s | 17.83 token/s | 99 |
| LFM2.5 350M | Q4_K_M | 29.43 token/s | 34.61 token/s | 1 |

GPU 后端通过了 14 项数值检查，1.2B 模型运行时也记录到了 GPU 调度。这些数据不能代表持续运行速度或回答质量。

将 1.2B 模型的上下文设为 8,192 token 后，一次合成检索测试输入了 7,620 token，模型找回了开头的六位校验码。整个请求耗时 281.95 秒，包含提示处理和生成。这只是一次检索检查，不能代表整体长上下文能力。

Gemma 4 E4B IQ2_M 在 One S 的一次 CPU 测试中生成 32 个 token，速度为 1.71 token/s；该模型的 GPU 推理尚未验证。Series X、长期稳定性、实体鼠标和中文输入法组合操作也尚未独立测试。

## 源码与子模块

本分支基于 xllama 提交 `a13d237f547577735d2e5c4d60689dfa27135ce9`，包含父仓库的 One S 适配。llama.cpp 子模块固定在 `b29c606e28a01b1bc8c1351026a0fa6e616bf6c4`；子模块内部改动保存在 `patches/xbox-one-s/llama-cpp.patch`，需要单独应用。

初始化子模块后，先在 `llama.cpp` 中检查补丁，再应用。父仓库改动和子模块补丁均已针对各自基准提交检查。短文本测试数据见 `patches/xbox-one-s/benchmark-summary.csv`。

## 构建状态

实机测试包使用实验性 Linux 交叉编译工具链、Windows SDK、运行库和本机测试证书构建。目前尚未提供一键构建方式，也没有在干净环境中完成复现；Windows MSBuild 尚未测试。后端和测试详情见 `docs/gguf-gpu-decode.md`。

本分支没有新增模型权重、MSIX、签名私钥、设备日志或账户凭据。网页和 API 通过无认证的局域网 HTTP 提供；使用服务时，Xbox 应用需要保持前台运行。

## 来源与许可证

本工作基于 [xllama](https://github.com/gianlucamazza/xllama)，上游采用 MIT 许可证。发布 Fork 时应保留上游版权声明和许可证。llama.cpp、模型权重、运行库及其他依赖分别适用各自的许可证和分发条款。
