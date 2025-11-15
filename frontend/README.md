# NFT Lottery UI

Minimal React + TypeScript frontend for an NFT lottery UI.

Features:
- 展示总的 NFT 数量
- 录入 NFT 地址（奖励池）
- 可选：输入参与者地址（换行或逗号分隔），若留空则使用 NFT 地址作为参与者池
- 填写抽奖 NFT 总数与中奖地址数量，点击“开始抽奖”展示随机结果

快速开始:

```bash
cd frontend
npm install
npm run dev
```

页面将启动在 `http://localhost:5173`（或终端输出的地址）。
# Aptos NFT Lottery Frontend (Demo)

这是一个最小 React + TypeScript 前端示例，提供 NFT 抽奖页面（仅前端模拟选择与验证）。

功能：
- 展示已录入的 NFT 总数量
- 表格录入/编辑 NFT 地址（可增删行）
- 填写“抽奖 NFT 总数”和“中奖地址数量”并点击“创建抽奖”生成预览结果（JSON）

快速运行：

1. 进入目录：

```bash
cd /data/crypto/Aditto/testaptosnft/frontend
```

2. 安装依赖：

```bash
npm install
```

3. 启动开发服务器：

```bash
npm run dev
```

打开浏览器访问 Vite 控制台给出的本地地址（通常是 `http://localhost:5173`）。

说明：
- 该示例仅实现前端交互与基本校验；实际上链或对 NFT 转移需集成 Aptos SDK / 钱包并调用链上合约或后端服务。
