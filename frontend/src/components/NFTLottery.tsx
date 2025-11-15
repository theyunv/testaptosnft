import React, { useState } from 'react'

type Assignment = {
  winner: string
  nft?: string
}

function shuffle<T>(arr: T[]): T[] {
  const a = arr.slice()
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

export default function NFTLottery() {
  const [nftAddresses, setNftAddresses] = useState<string[]>([''])
  const [participantsText, setParticipantsText] = useState('')
  const [rewardCount, setRewardCount] = useState<number>(1)
  const [winnersCount, setWinnersCount] = useState<number>(1)
  const [results, setResults] = useState<Assignment[] | null>(null)
  const totalNFTs = nftAddresses.filter(a => a.trim() !== '').length

  const updateAddress = (index: number, value: string) => {
    const copy = nftAddresses.slice()
    copy[index] = value
    setNftAddresses(copy)
  }

  const addRow = () => setNftAddresses(prev => [...prev, ''])
  const removeRow = (index: number) => setNftAddresses(prev => prev.filter((_, i) => i !== index))

  const startLottery = () => {
    const pool = nftAddresses.map(a => a.trim()).filter(a => a !== '')
    const participants = participantsText
      .split(/\s*[\n,;]\s*/)
      .map(s => s.trim())
      .filter(s => s !== '')
    const participantPool = participants.length > 0 ? participants : pool.slice()

    if (participantPool.length === 0) {
      alert('没有参与者或可用 NFT 地址，请先录入。')
      return
    }

    if (winnersCount <= 0) {
      alert('中奖地址数量必须大于 0')
      return
    }

    if (winnersCount > participantPool.length) {
      alert('中奖地址数量不能超过参与者数量')
      return
    }

    const shuffledParticipants = shuffle(participantPool)
    const winners = shuffledParticipants.slice(0, winnersCount)

    // Prepare reward NFTs pool
    const rewardPool = pool.slice()
    if (rewardPool.length === 0) {
      // 允许没有奖励 NFT，仅显示中奖地址
      setResults(winners.map(w => ({ winner: w })))
      return
    }

    const shuffledRewards = shuffle(rewardPool)

    // Assign NFTs to winners up to min(rewardCount, winnersCount)
    const assignments: Assignment[] = winners.map((w, i) => ({ winner: w }))
    const assignable = Math.min(rewardCount, shuffledRewards.length, winnersCount)
    for (let i = 0; i < assignable; i++) {
      assignments[i].nft = shuffledRewards[i]
    }

    setResults(assignments)
  }

  return (
    <div className="lottery">
      <section className="summary">
        <strong>总的 NFT 数量：</strong> {totalNFTs}
      </section>

      <section className="table">
        <h3>录入 NFT 地址（奖励池）</h3>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>NFT 地址 / 标识</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {nftAddresses.map((addr, idx) => (
              <tr key={idx}>
                <td>{idx + 1}</td>
                <td>
                  <input
                    value={addr}
                    onChange={e => updateAddress(idx, e.target.value)}
                    placeholder="例如：0x123... 或 ipfs://..."
                    style={{ width: '100%' }}
                  />
                </td>
                <td>
                  <button onClick={() => removeRow(idx)} aria-label="删除">删除</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <div style={{ marginTop: 8 }}>
          <button onClick={addRow}>新增一行</button>
        </div>
      </section>

      <section className="participants">
        <h3>参与者地址（可选，换行或逗号分隔）。若留空，则使用 NFT 地址作为参与者池。</h3>
        <textarea
          rows={4}
          value={participantsText}
          onChange={e => setParticipantsText(e.target.value)}
          placeholder="每行一个地址，或用逗号/分号分隔"
        />
      </section>

      <section className="controls">
        <label>
          抽奖 NFT 总数：
          <input type="number" min={0} value={rewardCount} onChange={e => setRewardCount(Number(e.target.value))} />
        </label>
        <label>
          中奖地址数量：
          <input type="number" min={1} value={winnersCount} onChange={e => setWinnersCount(Number(e.target.value))} />
        </label>
        <div>
          <button onClick={startLottery}>开始抽奖</button>
        </div>
      </section>

      <section className="results">
        <h3>抽奖结果</h3>
        {results == null ? (
          <p>尚无结果，点击 “开始抽奖” 查看。</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>中奖地址</th>
                <th>分配到的 NFT（若有）</th>
              </tr>
            </thead>
            <tbody>
              {results.map((r, i) => (
                <tr key={i}>
                  <td>{i + 1}</td>
                  <td style={{ wordBreak: 'break-all' }}>{r.winner}</td>
                  <td style={{ wordBreak: 'break-all' }}>{r.nft ?? '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  )
}
