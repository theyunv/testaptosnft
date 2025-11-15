import React, { useState } from "react";

type NFTRow = { id: number; address: string };

export default function LotteryPage() {
  const [rows, setRows] = useState<NFTRow[]>([{ id: 1, address: "" }]);
  const [nextId, setNextId] = useState(2);
  const [raffleCount, setRaffleCount] = useState<number>(1);
  const [winnerCount, setWinnerCount] = useState<number>(1);
  const [lastResult, setLastResult] = useState<string | null>(null);

  const totalNFTs = rows.filter((r) => r.address.trim() !== "").length;

  function updateRow(id: number, address: string) {
    setRows((s) => s.map((r) => (r.id === id ? { ...r, address } : r)));
  }

  function addRow() {
    setRows((s) => [...s, { id: nextId, address: "" }]);
    setNextId((n) => n + 1);
  }

  function removeRow(id: number) {
    setRows((s) => s.filter((r) => r.id !== id));
  }

  function handleCreateLottery() {
    setLastResult(null);
    // validation
    if (raffleCount <= 0) {
      setLastResult("抽奖 NFT 总数必须大于 0。");
      return;
    }
    if (winnerCount <= 0) {
      setLastResult("中奖地址数量必须大于 0。");
      return;
    }

    const validAddrs = rows.map((r) => r.address.trim()).filter((a) => a !== "");

    if (raffleCount > validAddrs.length) {
      setLastResult("错误：录入的 NFT 地址数小于抽奖 NFT 总数。");
      return;
    }
    if (winnerCount > validAddrs.length) {
      setLastResult("错误：录入的地址数少于中奖人数。");
      return;
    }
    if (winnerCount > raffleCount) {
      setLastResult("错误：中奖人数不能大于抽奖 NFT 总数。");
      return;
    }

    // 简单示例：随机从 validAddrs 中选 raffleCount 个 NFT 作为奖池，
    // 然后从这 rafflePool 中随机选出 winnerCount 个地址作为中奖地址。
    // （实际应由链上/后端来决定及转移资产，这里仅为前端演示）

    // pick raffle pool
    const shuffled = [...validAddrs].sort(() => Math.random() - 0.5);
    const rafflePool = shuffled.slice(0, raffleCount);

    // pick winners from rafflePool
    const winners = [...rafflePool].sort(() => Math.random() - 0.5).slice(0, winnerCount);

    const payload = {
      rafflePool,
      winners,
      raffleCount,
      winnerCount
    };

    setLastResult(JSON.stringify(payload, null, 2));
  }

  return (
    <div className="lottery-page">
      <section className="summary">
        <strong>总录入 NFT 数量</strong>
        <div className="big-number">{totalNFTs}</div>
      </section>

      <section className="inputs">
        <h2>录入 NFT 地址</h2>
        <table className="nft-table">
          <thead>
            <tr>
              <th>#</th>
              <th>NFT 地址</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r, idx) => (
              <tr key={r.id}>
                <td>{idx + 1}</td>
                <td>
                  <input
                    type="text"
                    value={r.address}
                    placeholder="0x... 或 对象地址"
                    onChange={(e) => updateRow(r.id, e.target.value)}
                    className="addr-input"
                  />
                </td>
                <td>
                  <button onClick={() => removeRow(r.id)} className="btn small">删除</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="controls">
          <button onClick={addRow} className="btn">添加一行</button>
        </div>
      </section>

      <section className="lottery-config">
        <h2>创建抽奖</h2>
        <div className="field">
          <label>抽奖 NFT 总数:</label>
          <input
            type="number"
            min={1}
            value={raffleCount}
            onChange={(e) => setRaffleCount(Number(e.target.value))}
          />
        </div>
        <div className="field">
          <label>中奖地址数量:</label>
          <input
            type="number"
            min={1}
            value={winnerCount}
            onChange={(e) => setWinnerCount(Number(e.target.value))}
          />
        </div>
        <div className="field">
          <button onClick={handleCreateLottery} className="btn primary">创建抽奖</button>
        </div>
      </section>

      <section className="result">
        <h2>结果 / 载荷预览</h2>
        {lastResult ? (
          <pre className="json-result">{lastResult}</pre>
        ) : (
          <div className="muted">点击“创建抽奖”以查看抽奖池与中奖地址（仅前端模拟）</div>
        )}
      </section>
    </div>
  );
}
