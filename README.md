# HONBU: Samurai Fighter Logistics OS (本部：在日後勤共享 OS)

## 專案概述 (Overview)
**HONBU (本部)** 是指武術流派的總部基地。作為 ONE Samurai 的後勤共享作業系統，HONBU 專注於解決大量國際選手赴日參賽時所面臨的簽證、住宿、場館預約與行程協調等繁瑣的 B2B 物流與資源調度問題。

## 核心痛點解決
目前跨國賽事的選手後勤多仰賴 Email 與 Excel，極易出現溝通失誤、場館預約衝突，進而損害選手的備戰體驗。HONBU 打造了一個安全、可信任的多方協作平台，確保所有資源調度準確無誤。

## 為何選擇 Sui Network
*   **稀缺資源的防呆鎖定**：運用 Move 語言特殊的資源導向模型（Resource Model），在底層語言級別防範「雙重預約」。一個訓練時段一旦被鎖定為專屬物件，即天然杜絕重複預訂的可能。
*   **跨界多方信任層**：後勤協調涉及 ONE 官方、日本當地道館、經紀人等多方角色。Sui 提供了具備權限控制的共享狀態層，打破各方內部系統的藩籬，實現資訊安全共享。
*   **為未來粉絲生態鋪路**：當選手的非敏感行程（如道館到訪紀錄）標準化為 Sui 物件後，未來能無縫授權給粉絲端的應用（如 KIZUNA 通行證的「道館巡禮打卡」活動）調用，發揮極大的生態綜效。

## 目標對象與 GTM 策略
*   **對象**：ONE 賽事營運團隊、選手經紀人、日本在地合作道館與飯店。
*   **策略**：先從內部 B2B 協作切入，取代現有的 Excel 管理模式。待資料結構完善後，逐步將去識別化的資源數據對外開放給粉絲行銷生態系。

## ⚠️ Demo-only AgentCap bootstrap

`/api/agent-cap` signs with the deployed AdminCap held in `ADMIN_PRIVATE_KEY_BECH32` env var.
This is acceptable for hackathon demo only. In production the AgentCap issuance MUST be gated
by KYC / invite code, and the admin key MUST live in a KMS (AWS KMS / GCP HSM), never an env var.
