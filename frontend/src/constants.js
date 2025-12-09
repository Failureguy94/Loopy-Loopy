// Deployed LooperVault contract address on Sepolia
export const LOOPER_VAULT_ADDRESS = "0x10bA2B80361C686340ec09A04ee0BA4893531B9E";

// LooperVault ABI (essential functions only)
export const LOOPER_VAULT_ABI = [
    {
        "inputs": [],
        "name": "deposit",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "requestUnwind",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "targetLTV",
        "outputs": [{ "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "maxSlippage",
        "outputs": [{ "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "minLTVDelta",
        "outputs": [{ "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "absoluteMaxLoops",
        "outputs": [{ "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getCurrentLTV",
        "outputs": [{ "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getHealthFactor",
        "outputs": [{ "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{ "name": "user", "type": "address" }],
        "name": "getPosition",
        "outputs": [
            {
                "components": [
                    { "name": "totalCollateral", "type": "uint256" },
                    { "name": "totalDebt", "type": "uint256" },
                    { "name": "currentLTV", "type": "uint256" },
                    { "name": "previousLTV", "type": "uint256" },
                    { "name": "loopsCompleted", "type": "uint256" },
                    { "name": "isActive", "type": "bool" },
                    { "name": "isLooping", "type": "bool" }
                ],
                "type": "tuple"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{ "name": "user", "type": "address" }],
        "name": "needsMoreLoops",
        "outputs": [{ "type": "bool" }],
        "stateMutability": "view",
        "type": "function"
    },
    // Events
    {
        "anonymous": false,
        "inputs": [
            { "indexed": true, "name": "user", "type": "address" },
            { "indexed": false, "name": "initialAmount", "type": "uint256" },
            { "indexed": false, "name": "targetLTV", "type": "uint256" },
            { "indexed": false, "name": "timestamp", "type": "uint256" }
        ],
        "name": "LoopRequested",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            { "indexed": true, "name": "user", "type": "address" },
            { "indexed": false, "name": "loopNumber", "type": "uint256" },
            { "indexed": false, "name": "borrowed", "type": "uint256" },
            { "indexed": false, "name": "swapped", "type": "uint256" },
            { "indexed": false, "name": "supplied", "type": "uint256" },
            { "indexed": false, "name": "currentLTV", "type": "uint256" }
        ],
        "name": "LoopStepCompleted",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            { "indexed": true, "name": "user", "type": "address" },
            { "indexed": false, "name": "finalLTV", "type": "uint256" },
            { "indexed": false, "name": "totalLoops", "type": "uint256" },
            { "indexed": false, "name": "totalCollateral", "type": "uint256" },
            { "indexed": false, "name": "totalDebt", "type": "uint256" }
        ],
        "name": "LoopingCompleted",
        "type": "event"
    }
];

// Legacy exports for backwards compatibility
export const ORIGIN_ADDRESS = LOOPER_VAULT_ADDRESS;
export const ORIGIN_ABI = LOOPER_VAULT_ABI;
