import { useState, useEffect, useCallback } from 'react';
import { LOOPER_VAULT_ADDRESS, LOOPER_VAULT_ABI } from "./constants";
import './index.css';

function App() {
  const [account, setAccount] = useState(null);
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [contract, setContract] = useState(null);
  const [depositAmount, setDepositAmount] = useState('0.05');
  const [logs, setLogs] = useState([]);
  const [isLooping, setIsLooping] = useState(false);
  const [stats, setStats] = useState({
    targetLTV: 7500n,
    currentLTV: 0n,
    healthFactor: 0n,
  });

  const addLog = (msg, type = 'info') => {
    const time = new Date().toLocaleTimeString();
    setLogs(prev => [{ time, msg, type }, ...prev].slice(0, 50));
  };

  // Connect wallet
  const connectWallet = async () => {
    if (!window.ethereum) {
      addLog("Please install MetaMask!", "error");
      return;
    }

    try {
      addLog("Connecting wallet...", "info");
      const { ethers } = await import('ethers');

      // Request accounts
      const accounts = await window.ethereum.request({
        method: 'eth_requestAccounts'
      });

      // Check network (Sepolia = 11155111)
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });
      if (chainId !== '0xaa36a7') {
        addLog("Switching to Sepolia...", "warning");
        try {
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: '0xaa36a7' }],
          });
        } catch (switchError) {
          addLog("Please switch to Sepolia network manually", "error");
          return;
        }
      }

      const browserProvider = new ethers.BrowserProvider(window.ethereum);
      const userSigner = await browserProvider.getSigner();
      const looperContract = new ethers.Contract(
        LOOPER_VAULT_ADDRESS,
        LOOPER_VAULT_ABI,
        userSigner
      );

      setProvider(browserProvider);
      setSigner(userSigner);
      setContract(looperContract);
      setAccount(accounts[0]);

      addLog(`Connected: ${accounts[0].slice(0, 6)}...${accounts[0].slice(-4)}`, "success");

      // Load initial stats
      loadStats(looperContract);
    } catch (error) {
      addLog(`Connection failed: ${error.message}`, "error");
    }
  };

  // Load contract stats
  const loadStats = async (contractInstance) => {
    const c = contractInstance || contract;
    if (!c) return;

    try {
      const [targetLTV, currentLTV, healthFactor] = await Promise.all([
        c.targetLTV(),
        c.getCurrentLTV(),
        c.getHealthFactor(),
      ]);
      setStats({ targetLTV, currentLTV, healthFactor });
    } catch (error) {
      console.error("Failed to load stats:", error);
    }
  };

  // Deposit
  const handleDeposit = async () => {
    if (!contract || !signer) {
      addLog("Please connect wallet first", "error");
      return;
    }

    try {
      setIsLooping(true);
      const { ethers } = await import('ethers');
      const amountWei = ethers.parseEther(depositAmount);

      addLog(`Depositing ${depositAmount} ETH...`, "info");

      const tx = await contract.deposit({ value: amountWei });
      addLog(`Transaction sent: ${tx.hash.slice(0, 10)}...`, "info");

      const receipt = await tx.wait();
      addLog("✅ Deposit confirmed! Looping started.", "success");

      // Reload stats
      setTimeout(() => loadStats(), 2000);
    } catch (error) {
      addLog(`❌ Error: ${error.message}`, "error");
    } finally {
      setIsLooping(false);
    }
  };

  // Request Unwind
  const handleUnwind = async () => {
    if (!contract) return;

    try {
      addLog("Requesting position unwind...", "warning");
      const tx = await contract.requestUnwind();
      addLog(`Unwind request sent: ${tx.hash.slice(0, 10)}...`, "info");
      await tx.wait();
      addLog("✅ Unwind requested!", "success");
    } catch (error) {
      addLog(`❌ Unwind error: ${error.message}`, "error");
    }
  };

  // Format helpers
  const formatLTV = (ltv) => {
    if (!ltv) return '0.00%';
    return (Number(ltv) / 100).toFixed(2) + '%';
  };

  const formatHealthFactor = (hf) => {
    if (!hf) return '∞';
    const value = Number(hf) / 1e18;
    if (value > 100) return '∞';
    return value.toFixed(2);
  };

  const getHealthFactorClass = (hf) => {
    if (!hf) return 'success';
    const value = Number(hf) / 1e18;
    if (value >= 1.5) return 'success';
    if (value >= 1.2) return 'warning';
    return 'error';
  };

  // Listen for account changes
  useEffect(() => {
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', (accounts) => {
        if (accounts.length === 0) {
          setAccount(null);
          addLog("Wallet disconnected", "warning");
        } else {
          setAccount(accounts[0]);
          addLog(`Account changed: ${accounts[0].slice(0, 6)}...`, "info");
        }
      });
    }
  }, []);

  // Refresh stats periodically
  useEffect(() => {
    if (contract) {
      const interval = setInterval(() => loadStats(), 10000);
      return () => clearInterval(interval);
    }
  }, [contract]);

  return (
    <div className="app-container">
      {/* Header */}
      <header className="header">
        <div className="logo">
          <div className="logo-icon">🔄</div>
          <span className="logo-text">Reactive Looper</span>
        </div>
        {account ? (
          <button className="connect-btn connected">
            {account.slice(0, 6)}...{account.slice(-4)}
          </button>
        ) : (
          <button className="connect-btn" onClick={connectWallet}>
            Connect Wallet
          </button>
        )}
      </header>

      {/* Main Content */}
      <main className="main-content">
        {/* Left Panel - Deposit */}
        <div className="card slide-up" style={{ animationDelay: '0.1s' }}>
          <div className="card-header">
            <div className="card-icon">⚡</div>
            <h2 className="card-title">Leverage Loop</h2>
          </div>

          <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
            Deposit ETH to automatically create a leveraged position on Aave.
            The Reactive Network orchestrates multi-step supply/borrow/swap loops.
          </p>

          <div className="input-group">
            <label className="input-label">Deposit Amount</label>
            <div className="input-wrapper">
              <input
                type="number"
                className="input-field"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                min="0.01"
                step="0.01"
                disabled={isLooping}
              />
              <span className="input-suffix">ETH</span>
            </div>
          </div>

          <div className="progress-container">
            <div className="progress-header">
              <span className="progress-label">Target LTV</span>
              <span className="progress-value">{formatLTV(stats.targetLTV)}</span>
            </div>
            <div className="progress-bar">
              <div
                className="progress-fill"
                style={{ width: `${Number(stats.targetLTV) / 100}%` }}
              />
            </div>
          </div>

          <button
            className="btn btn-primary"
            onClick={handleDeposit}
            disabled={!account || isLooping || parseFloat(depositAmount) < 0.01}
          >
            {isLooping ? '⏳ Processing...' : '🚀 Start Leverage Loop'}
          </button>

          <ul className="feature-list">
            <li className="feature-item">
              <span className="feature-icon">✓</span>
              <span className="feature-text">Automated multi-step looping</span>
            </li>
            <li className="feature-item">
              <span className="feature-icon">✓</span>
              <span className="feature-text">Dynamic termination (no fixed iterations)</span>
            </li>
            <li className="feature-item">
              <span className="feature-icon">✓</span>
              <span className="feature-text">Slippage protection (max 1%)</span>
            </li>
            <li className="feature-item">
              <span className="feature-icon">✓</span>
              <span className="feature-text">Health factor monitoring (min 1.5)</span>
            </li>
          </ul>
        </div>

        {/* Right Panel - Position */}
        <div className="card slide-up" style={{ animationDelay: '0.2s' }}>
          <div className="card-header">
            <div className="card-icon">📊</div>
            <h2 className="card-title">Position Status</h2>
          </div>

          <div className="stats-grid">
            <div className="stat-item">
              <div className="stat-label">Current LTV</div>
              <div className="stat-value">{formatLTV(stats.currentLTV)}</div>
            </div>
            <div className="stat-item">
              <div className="stat-label">Target LTV</div>
              <div className="stat-value">{formatLTV(stats.targetLTV)}</div>
            </div>
            <div className="stat-item">
              <div className="stat-label">Health Factor</div>
              <div className={`stat-value ${getHealthFactorClass(stats.healthFactor)}`}>
                {formatHealthFactor(stats.healthFactor)}
              </div>
            </div>
            <div className="stat-item">
              <div className="stat-label">Status</div>
              <div className={`status-badge ${isLooping ? 'pending' : account ? 'active' : 'inactive'}`}>
                <span className="status-dot"></span>
                {isLooping ? 'Looping' : account ? 'Ready' : 'Disconnected'}
              </div>
            </div>
          </div>

          <div className="progress-container">
            <div className="progress-header">
              <span className="progress-label">Loop Progress</span>
              <span className="progress-value">
                {stats.currentLTV && stats.targetLTV
                  ? Math.min(100, Math.round((Number(stats.currentLTV) / Number(stats.targetLTV)) * 100))
                  : 0}%
              </span>
            </div>
            <div className="progress-bar">
              <div
                className="progress-fill"
                style={{
                  width: `${stats.currentLTV && stats.targetLTV
                    ? Math.min(100, (Number(stats.currentLTV) / Number(stats.targetLTV)) * 100)
                    : 0}%`
                }}
              />
            </div>
          </div>

          <button
            className="btn btn-danger"
            onClick={handleUnwind}
            disabled={!account || isLooping}
          >
            🔓 Safe Unwind Position
          </button>

          {/* Logs */}
          <div style={{ marginTop: '1.5rem' }}>
            <h3 style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', marginBottom: '0.75rem' }}>
              Activity Log
            </h3>
            <div className="logs-panel">
              {logs.length === 0 ? (
                <div style={{ color: 'var(--text-muted)', padding: '1rem', textAlign: 'center' }}>
                  Connect wallet to get started...
                </div>
              ) : (
                logs.map((log, i) => (
                  <div key={i} className="log-entry">
                    <span className="log-time">{log.time}</span>
                    <span className={`log-message ${log.type}`}>{log.msg}</span>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="footer">
        <span className="footer-text">
          Built with 💜 for the Reactive Network Hackathon
        </span>
        <div className="footer-links">
          <a
            href={`https://sepolia.etherscan.io/address/${LOOPER_VAULT_ADDRESS}`}
            target="_blank"
            rel="noopener noreferrer"
            className="footer-link"
          >
            View Contract ↗
          </a>
          <a
            href="https://reactive.network"
            target="_blank"
            rel="noopener noreferrer"
            className="footer-link"
          >
            Reactive Network ↗
          </a>
        </div>
      </footer>
    </div>
  );
}

export default App;
