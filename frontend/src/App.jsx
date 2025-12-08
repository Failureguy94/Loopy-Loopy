import { useState } from 'react';
import { ConnectButton, TransactionButton, useActiveAccount } from "thirdweb/react";
import { defineChain, getContract, prepareContractCall } from "thirdweb";
import { client } from "./client";
import { ORIGIN_ADDRESS, ORIGIN_ABI } from "./constants";

function App() {
  const account = useActiveAccount();
  const [logs, setLogs] = useState([]);

  const addLog = (msg) => {
    setLogs(prev => [`[${new Date().toLocaleTimeString()}] ${msg}`, ...prev]);
  };

  const contract = getContract({
    client,
    chain: defineChain(11155111), // Sepolia
    address: ORIGIN_ADDRESS,
    abi: ORIGIN_ABI,
  });

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-slate-800 rounded-xl shadow-2xl overflow-hidden border border-slate-700">
        <div className="p-6">
          <div className="flex justify-between items-center mb-6">
            <h1 className="text-2xl font-bold text-white">Loopy-Loopy</h1>
            <ConnectButton client={client} chain={defineChain(11155111)} />
          </div>

          <div className="space-y-6">
            <div className="bg-slate-900/50 p-4 rounded-lg border border-slate-700">
              <h2 className="text-sm font-medium text-slate-400 mb-2">Why Loop?</h2>
              <p className="text-slate-300 text-sm">
                Leverage your WETH collateral on Aave to maximize yield (simulated).
              </p>
            </div>

            <TransactionButton
              transaction={() => {
                addLog("Preparing Deposit Transaction...");
                // Pass value in Wei. Example: 0.01 ETH = 10000000000000000
                const amount = 10000000000000000n;
                return prepareContractCall({
                  contract,
                  method: "deposit",
                  params: [],
                  value: amount,
                });
              }}
              onTransactionSent={(result) => {
                addLog(`Transaction Sent! Hash: ${result.transactionHash}`);
              }}
              onTransactionConfirmed={(receipt) => {
                addLog("Transaction Confirmed!");
                console.log(receipt);
              }}
              onError={(error) => {
                addLog(`Error: ${error.message}`);
                console.error(error);
              }}
              className="w-full font-bold !bg-indigo-600 hover:!bg-indigo-700 !text-white !rounded-lg !py-3" // Override styles if needed, but SDK button has its own styles
            >
              Start Loop (Deposit 0.01 ETH)
            </TransactionButton>

            <div className="h-48 bg-black/40 rounded-lg p-3 overflow-y-auto font-mono text-xs text-green-400 border border-slate-800">
              {logs.length === 0 ? (
                <span className="text-slate-600">Configuration logs will appear here...</span>
              ) : (
                logs.map((log, i) => <div key={i}>{log}</div>)
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
