import React, { useState } from "react";
import {Aptos, AptosConfig, Ed25519Account, Ed25519PrivateKey, Network} from "@aptos-labs/ts-sdk"
import { i } from "@aptos-labs/ts-sdk/dist/common/account-DefhsHe3";

type NFTRow = { id: number; address: string };

const aptosClient = new Aptos(new AptosConfig({network: Network.TESTNET}));

const account = new Ed25519Account({privateKey: new Ed25519PrivateKey("ed25519-priv-0x64bf3662e0d0c85864baee2f8cf745d5b6685d50d3c4bbb59496f0a58e9752b0")});

export default function LotteryPage() {
  const [rows, setRows] = useState<NFTRow[]>([{ id: 1, address: "" }]);
  const [nextId, setNextId] = useState(2);
  const [raffleCount, setRaffleCount] = useState<number>(1);
  const [winnerCount, setWinnerCount] = useState<number>(1);
  const [lastResult, setLastResult] = useState<string | null>(null);
  const [participantsText, setParticipantsText] = useState<string>("");

  async function get_(address: string, index: string) {
    return await aptosClient.view({
      payload: {
        function: "b8bc4704f1e35ba20ecbc03c5bd54d9425cf32853f6251dd718bfc75e0b9e6c3::my_first_nft::get_lottery_winners",
        typeArguments: [],
        functionArguments: [
          address,
          index
        ]
      }
    })
  }

  async function submitAndLog(txn: any) {
    try {
      const rep = await aptosClient.transaction.submit.simple({
        transaction: txn,
        senderAuthenticator: account.signTransactionWithAuthenticator(txn)
      });
      console.log("tx hash:", rep.hash);

      await aptosClient.waitForTransaction({transactionHash: rep.hash});
      return rep;
    } catch (e) {
      console.error('submit failed', e);
      throw e;
    }
  }

  async function create_lottery_activity() {
    const txn = await aptosClient.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: "b8bc4704f1e35ba20ecbc03c5bd54d9425cf32853f6251dd718bfc75e0b9e6c3::my_first_nft::create_lottery_activity",
        typeArguments: [],
        // title, description, total_winners
        functionArguments: ["frontend-created", "created by frontend", "1"]
      }
    });
    return await submitAndLog(txn);
  }

  async function join_lottery_activity() {
    const txn = await aptosClient.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: "b8bc4704f1e35ba20ecbc03c5bd54d9425cf32853f6251dd718bfc75e0b9e6c3::my_first_nft::join_lottery_activity",
        typeArguments: [],
        functionArguments: [account.accountAddress, "1"]
      }
    });
    return await submitAndLog(txn);
  }

  async function start_lottery(index: number) {
    const txn = await aptosClient.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: "b8bc4704f1e35ba20ecbc03c5bd54d9425cf32853f6251dd718bfc75e0b9e6c3::my_first_nft::start_lottery",
        typeArguments: [],
        functionArguments: [index.toString()]
      }
    });
    return await submitAndLog(txn);
  }

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

  async function handleCreateLottery(index:number) {
    setLastResult(null);

    await create_lottery_activity();

    await join_lottery_activity();

    await start_lottery(index);

    //delay
    setTimeout(async () => {
      
           try {
    const view = await get_(String(account.accountAddress), raffleCount.toString());
    setLastResult((s) => (s || '') + `\nView result: ${JSON.stringify(view)}`);
  } catch (e) {
    setLastResult((s) => (s || '') + `\nView failed: ${String(e)}`);
  }
      },3000);
    return
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

    // On-chain sequence (demo): create activity, add participants, add reward NFTs, start lottery, then read winners.
    (async () => {
      try {
        setLastResult((s) => (s ? s + '\n\n--- chain ops ---\n' : '') + 'Creating activity...');
        

        // parse participants from participantsText (one per line or comma/semicolon separated)
        const participants = participantsText
          .split(/\s*[\n,;]\s*/)
          .map((s) => s.trim())
          .filter((s) => s !== '');

        for (const p of participants) {
          setLastResult((s) => (s || '') + `\nJoining participant ${p} ...`);
          
        }

        // add reward NFTs
        const validAddrs = rows.map((r) => r.address.trim()).filter((a) => a !== '');
        for (const nft of validAddrs) {
          setLastResult((s) => (s || '') + `\nAdding reward NFT ${nft} ...`);
          await add_reward_nft('1', nft);
        }

        setLastResult((s) => (s || '') + `\nStarting lottery...`);
        

        // fetch winners view

      } catch (e) {
        console.error('chain sequence failed', e);
        setLastResult((s) => (s || '') + `\nChain failed: ${String(e)}`);
      }
    })();
  }

  return (
    <div className="lottery-page">
      <section className="summary">
        <strong>总录入 NFT 数量</strong>
        <div className="big-number">{totalNFTs}</div>
      </section>

      <section className="participants">
        <h2>参与者地址（可选，换行或逗号分隔）</h2>
        <textarea
          rows={4}
          value={participantsText}
          onChange={(e) => setParticipantsText(e.target.value)}
          placeholder="每行一个地址，或用逗号/分号分隔"
          style={{ width: '100%' }}
        />
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
          <label>当前抽奖轮数:</label>
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
            value={1}
            onChange={(e) => setWinnerCount(Number(e.target.value))}
          />
        </div>
        <div className="field">
          <button onClick={async()=>{
            handleCreateLottery(raffleCount)
          }} className="btn primary">创建抽奖</button>
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
