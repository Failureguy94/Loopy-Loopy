// Deployed LooperVault contract address on Sepolia
export const LOOPER_VAULT_ADDRESS = "0x10bA2B80361C686340ec09A04ee0BA4893531B9E";

// LooperVault ABI - essential functions only
export const LOOPER_VAULT_ABI = [
    // Deposit function
    "function deposit() external payable",

    // Unwind function
    "function requestUnwind() external",

    // View functions
    "function targetLTV() external view returns (uint256)",
    "function maxSlippage() external view returns (uint256)",
    "function minLTVDelta() external view returns (uint256)",
    "function absoluteMaxLoops() external view returns (uint256)",
    "function safeHealthFactor() external view returns (uint256)",
    "function minBorrowAmount() external view returns (uint256)",
    "function getCurrentLTV() external view returns (uint256)",
    "function getHealthFactor() external view returns (uint256)",
    "function needsMoreLoops(address user) external view returns (bool)",

    // Events
    "event LoopRequested(address indexed user, uint256 initialAmount, uint256 targetLTV, uint256 timestamp)",
    "event LoopStepCompleted(address indexed user, uint256 loopNumber, uint256 borrowed, uint256 swapped, uint256 supplied, uint256 currentLTV)",
    "event LoopingCompleted(address indexed user, uint256 finalLTV, uint256 totalLoops, uint256 totalCollateral, uint256 totalDebt)",
    "event UnwindRequested(address indexed user, uint256 timestamp)",
    "event UnwindCompleted(address indexed user, uint256 totalRepaid, uint256 finalCollateral)",
    "event LoopFailed(address indexed user, string reason)"
];
