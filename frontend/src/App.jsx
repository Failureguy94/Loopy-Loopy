import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { LOOPER_VAULT_ADDRESS, LOOPER_VAULT_ABI } from './constants';
import './App.css';

// Sepolia Chain ID
const SEPOLIA_CHAIN_ID = '0xaa36a7'; // 11155111 in hex

function App() {
  // State
  const [account, setAccount] = useState(null);
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [contract, setContract] = useState(null);
  const [chainId, setChainId] = useState(null);
  const [connectionStatus, setConnectionStatus] = useState('disconnected'); // disconnected, connecting, connected, error

  // Form state
  const [depositAmount, setDepositAmount] = useState('0.05');
  const [isLoading, setIsLoading] = useState(false);

  // Contract data
  const [targetLTV, setTargetLTV] = useState('75.00');
  const [currentLTV, setCurrentLTV] = useState('0.00');
  const [healthFactor, setHealthFactor] = useState('∞');
  const [loopProgress, setLoopProgress] = useState(0);

  // Logs
  const [logs, setLogs] = useState([]);

  // Add log entry
  const addLog = useCallback((message, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [{ timestamp, message, type }, ...prev].slice(0, 50));
    console.log(`[${type}] ${message}`);
  }, []);

  // Check if MetaMask is installed
  const isMetaMaskInstalled = () => {
    return typeof window.ethereum !== 'undefined' && window.ethereum.isMetaMask;
  };

  // Switch to Sepolia network
  const switchToSepolia = async () => {
    if (!window.ethereum) return false;

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: SEPOLIA_CHAIN_ID }],
      });
      return true;
    } catch (switchError) {
      // Chain not added, try to add it
      if (switchError.code === 4902) {
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: SEPOLIA_CHAIN_ID,
              chainName: 'Sepolia Testnet',
              nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
              rpcUrls: ['https://ethereum-sepolia-rpc.publicnode.com'],
              blockExplorerUrls: ['https://sepolia.etherscan.io'],
            }],
          });
          return true;
        } catch (addError) {
          addLog('Failed to add Sepolia network', 'error');
          return false;
        }
      }
      addLog('Failed to switch to Sepolia', 'error');
      return false;
    }
  };

  // Connect wallet
  const connectWallet = async () => {
    if (!isMetaMaskInstalled()) {
      addLog('Please install MetaMask!', 'error');
      setConnectionStatus('error');
      window.open('https://metamask.io/download/', '_blank');
      return;
    }

    try {
      setIsLoading(true);
      setConnectionStatus('connecting');
      addLog('Connecting to MetaMask...', 'info');

      // Request accounts
      const accounts = await window.ethereum.request({
        method: 'eth_requestAccounts',
      });

      if (!accounts || accounts.length === 0) {
        addLog('No accounts found', 'error');
        return;
      }

      // Check chain
      const currentChainId = await window.ethereum.request({ method: 'eth_chainId' });
      setChainId(currentChainId);

      if (currentChainId !== SEPOLIA_CHAIN_ID) {
        addLog('Switching to Sepolia testnet...', 'warning');
        const switched = await switchToSepolia();
        if (!switched) return;
      }

      // Setup ethers
      const browserProvider = new ethers.BrowserProvider(window.ethereum);
      const userSigner = await browserProvider.getSigner();

      // Setup contract
      const looperContract = new ethers.Contract(
        LOOPER_VAULT_ADDRESS,
        LOOPER_VAULT_ABI,
        userSigner
      );

      // Update state
      setProvider(browserProvider);
      setSigner(userSigner);
      setContract(looperContract);
      setAccount(accounts[0]);
      setConnectionStatus('connected');

      addLog(`Connected: ${accounts[0].slice(0, 6)}...${accounts[0].slice(-4)}`, 'success');
      addLog(`Contract: ${LOOPER_VAULT_ADDRESS}`, 'info');

      // Load contract data
      await loadContractData(looperContract);

    } catch (error) {
      console.error('Connection error:', error);
      setConnectionStatus('error');
      addLog(`Connection failed: ${error.message}`, 'error');
      if (error.code) {
        addLog(`Error code: ${error.code}`, 'error');
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Load contract data
  const loadContractData = async (contractInstance) => {
    const c = contractInstance || contract;
    if (!c) {
      addLog('No contract instance available', 'warning');
      return;
    }

    try {
      addLog('Loading contract data...', 'info');

      // Get target LTV
      const target = await c.targetLTV();
      const targetValue = Number(target) / 100;
      setTargetLTV(targetValue.toFixed(2));
      addLog(`Target LTV: ${targetValue.toFixed(2)}%`, 'success');

      // Try to get current LTV (might fail if no position)
      try {
        const current = await c.getCurrentLTV();
        const currentValue = Number(current) / 100;
        setCurrentLTV(currentValue.toFixed(2));

        // Calculate progress
        if (targetValue > 0) {
          const progress = Math.min(100, (currentValue / targetValue) * 100);
          setLoopProgress(progress);
        }
      } catch (e) {
        setCurrentLTV('0.00');
        setLoopProgress(0);
      }

      // Try to get health factor
      try {
        const hf = await c.getHealthFactor();
        const hfValue = Number(hf) / 1e18;
        setHealthFactor(hfValue > 100 ? '∞' : hfValue.toFixed(2));
      } catch (e) {
        setHealthFactor('∞');
      }

    } catch (error) {
      console.error('Failed to load contract data:', error);
      addLog(`Failed to load contract data: ${error.message}`, 'error');
      if (error.code === 'CALL_EXCEPTION') {
        addLog('Contract may not be deployed or ABI mismatch', 'error');
      }
    }
  };

  // Deposit ETH
  const handleDeposit = async () => {
    if (!contract || !signer) {
      addLog('Please connect wallet first', 'error');
      return;
    }

    // Validate deposit amount
    if (!depositAmount || parseFloat(depositAmount) < 0.01) {
      addLog('Minimum deposit is 0.01 ETH', 'error');
      return;
    }

    try {
      setIsLoading(true);
      const amount = ethers.parseEther(depositAmount);

      addLog(`Preparing deposit of ${depositAmount} ETH...`, 'info');
      addLog(`Contract address: ${LOOPER_VAULT_ADDRESS}`, 'info');

      // Check balance
      const balance = await provider.getBalance(account);
      const balanceEth = ethers.formatEther(balance);
      addLog(`Your balance: ${parseFloat(balanceEth).toFixed(4)} ETH`, 'info');

      if (balance < amount) {
        addLog('Insufficient balance', 'error');
        setIsLoading(false);
        return;
      }

      addLog('Sending transaction...', 'info');
      const tx = await contract.deposit({ value: amount });
      addLog(`✅ Transaction sent: ${tx.hash}`, 'success');
      addLog(`View on Etherscan: https://sepolia.etherscan.io/tx/${tx.hash}`, 'info');

      addLog('Waiting for confirmation...', 'info');
      const receipt = await tx.wait();
      addLog('✅ Deposit confirmed! Looping started.', 'success');
      addLog(`Block: ${receipt.blockNumber}`, 'info');
      addLog(`Gas used: ${receipt.gasUsed.toString()}`, 'info');

      // Refresh data after a delay
      setTimeout(() => loadContractData(), 3000);

    } catch (error) {
      console.error('Deposit error:', error);
      addLog(`❌ Deposit failed: ${error.reason || error.message}`, 'error');

      // Provide more detailed error info
      if (error.code === 'ACTION_REJECTED') {
        addLog('Transaction was rejected by user', 'warning');
      } else if (error.code === 'INSUFFICIENT_FUNDS') {
        addLog('Insufficient funds for transaction', 'error');
      } else if (error.code) {
        addLog(`Error code: ${error.code}`, 'error');
      }

      // Log error data if available
      if (error.data) {
        console.error('Error data:', error.data);
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Request unwind
  const handleUnwind = async () => {
    if (!contract) {
      addLog('Please connect wallet first', 'error');
      return;
    }

    try {
      setIsLoading(true);
      addLog('Requesting position unwind...', 'warning');
      addLog('This will safely close your leveraged position', 'info');

      const tx = await contract.requestUnwind();
      addLog(`✅ Unwind request sent: ${tx.hash}`, 'success');
      addLog(`View on Etherscan: https://sepolia.etherscan.io/tx/${tx.hash}`, 'info');

      addLog('Waiting for confirmation...', 'info');
      await tx.wait();
      addLog('✅ Unwind requested successfully!', 'success');

      setTimeout(() => loadContractData(), 3000);

    } catch (error) {
      console.error('Unwind error:', error);
      addLog(`❌ Unwind failed: ${error.reason || error.message}`, 'error');

      // Check for specific error codes
      if (error.data === '0x33cbf2bc') {
        addLog('⚠️ No active position found. You need to deposit first!', 'warning');
        addLog('Click "Start Leverage Loop" to create a position', 'info');
      } else if (error.code === 'ACTION_REJECTED') {
        addLog('Transaction was rejected by user', 'warning');
      } else if (error.code) {
        addLog(`Error code: ${error.code}`, 'error');
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Listen for account/chain changes
  useEffect(() => {
    if (!window.ethereum) return;

    const handleAccountsChanged = (accounts) => {
      if (accounts.length === 0) {
        setAccount(null);
        setContract(null);
        addLog('Wallet disconnected', 'warning');
      } else if (accounts[0] !== account) {
        setAccount(accounts[0]);
        addLog(`Account changed to ${accounts[0].slice(0, 6)}...`, 'info');
        if (contract) loadContractData();
      }
    };

    const handleChainChanged = (newChainId) => {
      setChainId(newChainId);
      if (newChainId !== SEPOLIA_CHAIN_ID) {
        addLog('Please switch to Sepolia testnet', 'warning');
      }
      window.location.reload();
    };

    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);

    return () => {
      window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum.removeListener('chainChanged', handleChainChanged);
    };
  }, [account, contract, addLog]);

  // Auto-refresh data
  useEffect(() => {
    if (contract) {
      const interval = setInterval(() => loadContractData(), 15000);
      return () => clearInterval(interval);
    }
  }, [contract]);

  // Get health factor color class
  const getHealthClass = () => {
    if (healthFactor === '∞') return 'success';
    const hf = parseFloat(healthFactor);
    if (hf >= 1.5) return 'success';
    if (hf >= 1.2) return 'warning';
    return 'error';
  };

  return (
    <div className="app">
      {/* Header */}
      <header className="header">
        <div className="logo">
          <div className="logo-icon">🔄</div>
          <span className="logo-text">Reactive Looper</span>
          {connectionStatus === 'connected' && (
            <span style={{ marginLeft: '10px', fontSize: '12px', color: '#4ade80' }}>
              • Connected
            </span>
          )}
          {connectionStatus === 'connecting' && (
            <span style={{ marginLeft: '10px', fontSize: '12px', color: '#fbbf24' }}>
              • Connecting...
            </span>
          )}
        </div>

        {account ? (
          <button className="btn btn-connected">
            <span className={chainId === SEPOLIA_CHAIN_ID ? 'dot-green' : 'dot-red'}></span>
            {account.slice(0, 6)}...{account.slice(-4)}
          </button>
        ) : (
          <button
            className="btn btn-primary"
            onClick={connectWallet}
            disabled={isLoading}
          >
            {isLoading ? 'Connecting...' : 'Connect Wallet'}
          </button>
        )}
      </header>

      {/* Main Content */}
      <main className="main">
        {/* Left Panel - Deposit */}
        <div className="card">
          <div className="card-header">
            <span className="card-icon">⚡</span>
            <h2>Leverage Loop</h2>
          </div>

          <p className="card-description">
            Deposit ETH to automatically create a leveraged position on Aave.
            The Reactive Network orchestrates multi-step supply/borrow/swap loops.
          </p>

          <div className="input-group">
            <label>Deposit Amount</label>
            <div className="input-wrapper">
              <input
                type="number"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                min="0.01"
                step="0.01"
                disabled={isLoading}
              />
              <span className="suffix">ETH</span>
            </div>
          </div>

          <div className="progress-group">
            <div className="progress-header">
              <span>Target LTV</span>
              <span>{targetLTV}%</span>
            </div>
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: `${parseFloat(targetLTV)}%` }}></div>
            </div>
          </div>

          <button
            className="btn btn-primary btn-full"
            onClick={handleDeposit}
            disabled={!account || isLoading || parseFloat(depositAmount) < 0.01}
          >
            {isLoading ? '⏳ Processing...' : '🚀 Start Leverage Loop'}
          </button>

          <ul className="features">
            <li><span className="check">✓</span> Automated multi-step looping</li>
            <li><span className="check">✓</span> Dynamic termination (no fixed iterations)</li>
            <li><span className="check">✓</span> Slippage protection (max 1%)</li>
            <li><span className="check">✓</span> Health factor monitoring (min 1.5)</li>
          </ul>
        </div>

        {/* Right Panel - Status */}
        <div className="card">
          <div className="card-header">
            <span className="card-icon">📊</span>
            <h2>Position Status</h2>
          </div>

          <div className="stats-grid">
            <div className="stat">
              <span className="stat-label">Current LTV</span>
              <span className="stat-value">{currentLTV}%</span>
            </div>
            <div className="stat">
              <span className="stat-label">Target LTV</span>
              <span className="stat-value">{targetLTV}%</span>
            </div>
            <div className="stat">
              <span className="stat-label">Health Factor</span>
              <span className={`stat-value ${getHealthClass()}`}>{healthFactor}</span>
            </div>
            <div className="stat">
              <span className="stat-label">Status</span>
              <span className={`status-badge ${account ? 'active' : 'inactive'}`}>
                <span className="status-dot"></span>
                {account ? 'Ready' : 'Disconnected'}
              </span>
            </div>
          </div>

          <div className="progress-group">
            <div className="progress-header">
              <span>Loop Progress</span>
              <span>{loopProgress.toFixed(0)}%</span>
            </div>
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: `${loopProgress}%` }}></div>
            </div>
          </div>

          <button
            className="btn btn-danger btn-full"
            onClick={handleUnwind}
            disabled={!account || isLoading}
          >
            🔓 Safe Unwind Position
          </button>

          {/* Activity Log */}
          <div className="logs-section">
            <h3>Activity Log</h3>
            <div className="logs">
              {logs.length === 0 ? (
                <div className="log-empty">Connect wallet to get started...</div>
              ) : (
                logs.map((log, i) => (
                  <div key={i} className="log-entry">
                    <span className="log-time">{log.timestamp}</span>
                    <span className={`log-message ${log.type}`}>{log.message}</span>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="footer">
        <span>Built with 💙 for the Reactive Network Hackathon</span>
        <div className="footer-links">
          <a
            href={`https://sepolia.etherscan.io/address/${LOOPER_VAULT_ADDRESS}`}
            target="_blank"
            rel="noopener noreferrer"
          >
            View Contract ↗
          </a>
          <a
            href="https://reactive.network"
            target="_blank"
            rel="noopener noreferrer"
          >
            Reactive Network ↗
          </a>
        </div>
      </footer>
    </div>
  );
}

export default App;
