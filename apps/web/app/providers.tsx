"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SuiClientProvider } from "@mysten/dapp-kit";
import { getFullnodeUrl } from "@mysten/sui/client";
import "@mysten/dapp-kit/dist/index.css";
import { useState } from "react";

const networks = { testnet: { url: getFullnodeUrl("testnet") } };

export function Providers({ children }: { children: React.ReactNode }) {
  const [qc] = useState(() => new QueryClient());
  return (
    <QueryClientProvider client={qc}>
      <SuiClientProvider networks={networks} defaultNetwork="testnet">
        {children}
      </SuiClientProvider>
    </QueryClientProvider>
  );
}
