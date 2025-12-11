// Import contract ABIs from JSON files
import LooperVaultABI from './constants/abi/LooperVault.json';
import addresses from './constants/addresses.json';

// Export contract address from addresses.json
export const LOOPER_VAULT_ADDRESS = addresses.sepolia.looperVault;

// Export full ABI from JSON
export const LOOPER_VAULT_ABI = LooperVaultABI;

// Export chain ID
export const SEPOLIA_CHAIN_ID = addresses.sepolia.chainId;

// Export callback sender (for reference)
export const CALLBACK_SENDER = addresses.sepolia.callbackSender;

