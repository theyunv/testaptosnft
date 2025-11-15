import React from 'react'
import LotteryPage from "./components/LotteryPage"

export default function App() {
  return (
    <div className="app">
      <header>
        <h1>NFT 抽奖页面</h1>
        <p>功能：展示 NFT 总数 / 录入 NFT 地址 / 启动抽奖</p>
      </header>
      <main>
        <LotteryPage />
      </main>
    </div>
  )
}
