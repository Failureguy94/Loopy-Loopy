// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ISharedInterfaces.sol";

interface IPoolDataProvider {
    function getReserveData(
        address asset
    )
        external
        view
        returns (
            uint256 unbacked,
            uint256 accruedToTreasuryScaled,
            uint256 totalAToken,
            uint256 totalStableDebt,
            uint256 totalVariableDebt,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,
            uint256 averageStableBorrowRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            uint40 lastUpdateTimestamp
        );
    function getReserveCaps(
        address asset
    ) external view returns (uint256 borrowCap, uint256 supplyCap);
}

contract LooperVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Sepolia Aave V3 Addresses
    address public constant AAVE_POOL =
        0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address public constant POOL_DATA_PROVIDER =
        0x3e9708d80f7B3e43118013075F7e95CE3AB31F31;

    // Sepolia DEX
    address public constant UNISWAP_ROUTER =
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

    // Sepolia Tokens
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;

    // Precision constants
    uint256 public constant PRECISION = 10000; // 100.00%
    uint256 public constant LTV_PRECISION = 1e4;
    uint256 public constant HEALTH_FACTOR_PRECISION = 1e18;

    uint256 public targetLTV = 7500; // 75.00% target LTV
    uint256 public maxSlippage = 100; // 1.00% max slippage
    uint256 public minBorrowAmount = 1e6; // Minimum borrow (1 USDC)
    uint256 public safeHealthFactor = 15e17; // 1.5 minimum health factor
    uint256 public minLTVDelta = 50; // 0.50% minimum LTV improvement per loop
    uint256 public absoluteMaxLoops = 20; // Safety limit (should never reach due to diminishing returns)

    // Reactive Network callback proxy
    address public callbackProxy;

    struct Position {
        uint256 totalCollateral; // Total WETH supplied
        uint256 totalDebt; // Total USDC borrowed
        uint256 currentLTV; // Current LTV (in basis points)
        uint256 previousLTV; // LTV before last loop (for delta calculation)
        uint256 loopsCompleted; // Number of loops executed
        bool isActive;
        bool isLooping; // Currently in looping process
    }

    mapping(address => Position) public positions;

    // Events for Reactive Network subscription
    event LoopRequested(
        address indexed user,
        uint256 initialAmount,
        uint256 targetLTV,
        uint256 timestamp
    );

    event LoopStepCompleted(
        address indexed user,
        uint256 loopNumber,
        uint256 borrowed,
        uint256 swapped,
        uint256 supplied,
        uint256 currentLTV
    );

    event LoopingCompleted(
        address indexed user,
        uint256 finalLTV,
        uint256 totalLoops,
        uint256 totalCollateral,
        uint256 totalDebt
    );

    event UnwindRequested(address indexed user, uint256 timestamp);

    event UnwindCompleted(address indexed user, uint256 returnedAmount);

    event LoopFailed(address indexed user, string reason, uint256 atLoop);

    error InsufficientDeposit();
    error PositionAlreadyExists();
    error NoActivePosition();
    error AlreadyLooping();
    error InsufficientLiquidity(uint256 available, uint256 required);
    error SlippageExceeded(uint256 expected, uint256 received);
    error BorrowCapExceeded(uint256 cap, uint256 totalBorrowed);
    error HealthFactorTooLow(uint256 current, uint256 minimum);
    error OnlyCallbackProxy();
    error TargetLTVReached();
    error DiminishingReturns(uint256 ltvDelta, uint256 minRequired);

    constructor(address _callbackProxy) Ownable(msg.sender) {
        callbackProxy = _callbackProxy;
    }

    modifier onlyCallbackProxy() {
        if (msg.sender != callbackProxy && msg.sender != address(this)) {
            revert OnlyCallbackProxy();
        }
        _;
    }

    function setCallbackProxy(address _proxy) external onlyOwner {
        callbackProxy = _proxy;
    }

    function setTargetLTV(uint256 _targetLTV) external onlyOwner {
        require(_targetLTV <= 8500, "Max 85% LTV");
        targetLTV = _targetLTV;
    }

    function setMaxSlippage(uint256 _maxSlippage) external onlyOwner {
        require(_maxSlippage <= 500, "Max 5% slippage");
        maxSlippage = _maxSlippage;
    }

    function setMinLTVDelta(uint256 _minLTVDelta) external onlyOwner {
        require(_minLTVDelta >= 10 && _minLTVDelta <= 500, "0.1-5% delta");
        minLTVDelta = _minLTVDelta;
    }

    /// @notice Deposit ETH and start leveraged looping
    /// @dev Emits LoopRequested for Reactive Network to orchestrate loops
    function deposit() external payable nonReentrant {
        if (msg.value < 0.01 ether) revert InsufficientDeposit();
        if (positions[msg.sender].isActive) revert PositionAlreadyExists();

        uint256 depositAmount = msg.value;

        // Wrap ETH to WETH
        IWETH(WETH).deposit{value: depositAmount}();

        // Initial supply to Aave
        IERC20(WETH).approve(AAVE_POOL, depositAmount);
        IPool(AAVE_POOL).supply(WETH, depositAmount, address(this), 0);

        // Initialize position
        positions[msg.sender] = Position({
            totalCollateral: depositAmount,
            totalDebt: 0,
            currentLTV: 0,
            previousLTV: 0,
            loopsCompleted: 0,
            isActive: true,
            isLooping: true
        });

        // Emit event for Reactive Network to start orchestration
        emit LoopRequested(
            msg.sender,
            depositAmount,
            targetLTV,
            block.timestamp
        );
    }

    /// @notice Execute one loop step: borrow -> swap -> supply
    /// @dev Called by Reactive Network callback proxy
    function executeLoopStep(
        address user
    ) external onlyCallbackProxy nonReentrant {
        Position storage pos = positions[user];
        if (!pos.isActive) revert NoActivePosition();
        if (!pos.isLooping) revert TargetLTVReached();

        // Safety limit (should never reach due to diminishing returns)
        if (pos.loopsCompleted >= absoluteMaxLoops) {
            pos.isLooping = false;
            emit LoopingCompleted(
                user,
                pos.currentLTV,
                pos.loopsCompleted,
                pos.totalCollateral,
                pos.totalDebt
            );
            return;
        }

        // Get current account data
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            ,
            ,
            uint256 healthFactor
        ) = IPool(AAVE_POOL).getUserAccountData(address(this));

        // Calculate current LTV
        uint256 currentLTV = totalCollateralBase > 0
            ? (totalDebtBase * PRECISION) / totalCollateralBase
            : 0;

        // Check if target LTV reached
        if (currentLTV >= targetLTV) {
            pos.isLooping = false;
            pos.currentLTV = currentLTV;
            emit LoopingCompleted(
                user,
                currentLTV,
                pos.loopsCompleted,
                pos.totalCollateral,
                pos.totalDebt
            );
            return;
        }

        // Check health factor
        if (healthFactor < safeHealthFactor) {
            pos.isLooping = false;
            emit LoopFailed(user, "HEALTH_FACTOR_TOO_LOW", pos.loopsCompleted);
            revert HealthFactorTooLow(healthFactor, safeHealthFactor);
        }

        // Calculate borrow amount (borrow 60% of available to be safe)
        uint256 borrowAmount = (availableBorrowsBase * 60) / 100;

        // Check minimum borrow
        if (borrowAmount < minBorrowAmount) {
            pos.isLooping = false;
            emit LoopingCompleted(
                user,
                currentLTV,
                pos.loopsCompleted,
                pos.totalCollateral,
                pos.totalDebt
            );
            return;
        }

        // Check borrow cap
        (uint256 borrowCap, ) = IPoolDataProvider(POOL_DATA_PROVIDER)
            .getReserveCaps(USDC);
        if (borrowCap > 0) {
            (
                ,
                ,
                ,
                ,
                uint256 totalVariableDebt,
                ,
                ,
                ,
                ,
                ,
                ,

            ) = IPoolDataProvider(POOL_DATA_PROVIDER).getReserveData(USDC);
            if (totalVariableDebt + borrowAmount > borrowCap * 1e6) {
                pos.isLooping = false;
                emit LoopFailed(
                    user,
                    "BORROW_CAP_EXCEEDED",
                    pos.loopsCompleted
                );
                revert BorrowCapExceeded(
                    borrowCap * 1e6,
                    totalVariableDebt + borrowAmount
                );
            }
        }

        // Execute borrow
        IPool(AAVE_POOL).borrow(USDC, borrowAmount, 2, 0, address(this));

        // Swap USDC to WETH with slippage protection
        uint256 wethReceived = _swapWithSlippageProtection(borrowAmount);

        // Supply swapped WETH back to Aave
        IERC20(WETH).approve(AAVE_POOL, wethReceived);
        IPool(AAVE_POOL).supply(WETH, wethReceived, address(this), 0);

        // Update position
        pos.loopsCompleted++;
        pos.totalCollateral += wethReceived;
        pos.totalDebt += borrowAmount;
        pos.previousLTV = currentLTV; // Store previous LTV for delta calculation

        // Get updated LTV
        (totalCollateralBase, totalDebtBase, , , , ) = IPool(AAVE_POOL)
            .getUserAccountData(address(this));
        uint256 newLTV = totalCollateralBase > 0
            ? (totalDebtBase * PRECISION) / totalCollateralBase
            : 0;
        pos.currentLTV = newLTV;

        emit LoopStepCompleted(
            user,
            pos.loopsCompleted,
            borrowAmount,
            wethReceived,
            wethReceived,
            newLTV
        );

        // Calculate LTV delta (improvement from this loop)
        uint256 ltvDelta = newLTV > currentLTV ? newLTV - currentLTV : 0;

        // Dynamic termination conditions:
        // 1. Target LTV reached
        // 2. LTV improvement too small (diminishing returns)
        // 3. Safety limit reached (failsafe)
        if (newLTV >= targetLTV) {
            pos.isLooping = false;
            emit LoopingCompleted(
                user,
                newLTV,
                pos.loopsCompleted,
                pos.totalCollateral,
                pos.totalDebt
            );
        } else if (ltvDelta < minLTVDelta && pos.loopsCompleted > 1) {
            // Diminishing returns - LTV gain too small to justify gas costs
            pos.isLooping = false;
            emit LoopFailed(user, "DIMINISHING_RETURNS", pos.loopsCompleted);
            emit LoopingCompleted(
                user,
                newLTV,
                pos.loopsCompleted,
                pos.totalCollateral,
                pos.totalDebt
            );
        }
        // Otherwise, continue looping (Reactive will trigger next step)
    }

    /// @notice Request safe unwind of leveraged position
    function requestUnwind() external nonReentrant {
        Position storage pos = positions[msg.sender];
        if (!pos.isActive) revert NoActivePosition();
        if (pos.isLooping) revert AlreadyLooping();

        emit UnwindRequested(msg.sender, block.timestamp);
    }

    /// @notice Execute safe unwind: withdraw -> swap -> repay -> repeat
    /// @dev Called by Reactive Network or directly
    function executeUnwind(
        address user
    ) external onlyCallbackProxy nonReentrant {
        Position storage pos = positions[user];
        if (!pos.isActive) revert NoActivePosition();

        // Get current debt
        (, uint256 totalDebtBase, , , , uint256 healthFactor) = IPool(AAVE_POOL)
            .getUserAccountData(address(this));

        uint256 iterations = 0;

        // Unwind loop: withdraw collateral -> swap to USDC -> repay debt
        while (totalDebtBase > 0 && iterations < absoluteMaxLoops) {
            // Calculate safe withdrawal amount (keep health factor > 1.5)
            uint256 withdrawAmount = _calculateSafeWithdraw(healthFactor);
            if (withdrawAmount == 0) break;

            // Withdraw WETH
            uint256 withdrawn = IPool(AAVE_POOL).withdraw(
                WETH,
                withdrawAmount,
                address(this)
            );

            // Swap WETH to USDC
            IERC20(WETH).approve(UNISWAP_ROUTER, withdrawn);
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: USDC,
                    fee: 3000,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: withdrawn,
                    amountOutMinimum: 0, // In production, calculate with oracle
                    sqrtPriceLimitX96: 0
                });
            uint256 usdcReceived = ISwapRouter(UNISWAP_ROUTER).exactInputSingle(
                params
            );

            // Repay debt
            IERC20(USDC).approve(AAVE_POOL, usdcReceived);
            IPool(AAVE_POOL).repay(USDC, usdcReceived, 2, address(this));

            // Update debt
            (, totalDebtBase, , , , healthFactor) = IPool(AAVE_POOL)
                .getUserAccountData(address(this));
            iterations++;
        }

        // Withdraw remaining collateral
        (uint256 totalCollateralBase, , , , , ) = IPool(AAVE_POOL)
            .getUserAccountData(address(this));
        if (totalCollateralBase > 0) {
            uint256 remainingWeth = IPool(AAVE_POOL).withdraw(
                WETH,
                type(uint256).max,
                address(this)
            );

            // Unwrap and send to user
            IWETH(WETH).withdraw(remainingWeth);
            (bool success, ) = user.call{value: remainingWeth}("");
            require(success, "ETH transfer failed");

            emit UnwindCompleted(user, remainingWeth);
        }

        // Clear position
        delete positions[user];
    }

    /// @notice Swap USDC to WETH with slippage protection
    function _swapWithSlippageProtection(
        uint256 usdcAmount
    ) internal returns (uint256) {
        // Calculate minimum WETH expected (simplified - in production use oracle)
        // Assuming ~2000 USDC per WETH, with slippage
        uint256 expectedWeth = (usdcAmount * 1e18) / (2000 * 1e6);
        uint256 minWeth = (expectedWeth * (PRECISION - maxSlippage)) /
            PRECISION;

        IERC20(USDC).approve(UNISWAP_ROUTER, usdcAmount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: USDC,
                tokenOut: WETH,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: usdcAmount,
                amountOutMinimum: minWeth,
                sqrtPriceLimitX96: 0
            });

        uint256 wethReceived = ISwapRouter(UNISWAP_ROUTER).exactInputSingle(
            params
        );

        if (wethReceived < minWeth) {
            revert SlippageExceeded(minWeth, wethReceived);
        }

        return wethReceived;
    }

    /// @notice Calculate safe withdrawal amount
    function _calculateSafeWithdraw(
        uint256 currentHealthFactor
    ) internal view returns (uint256) {
        if (currentHealthFactor <= safeHealthFactor) return 0;

        // Withdraw up to 20% of collateral per iteration
        (uint256 totalCollateralBase, , , , , ) = IPool(AAVE_POOL)
            .getUserAccountData(address(this));
        return (totalCollateralBase * 20) / 100;
    }

    function getPosition(address user) external view returns (Position memory) {
        return positions[user];
    }

    function getCurrentLTV() external view returns (uint256) {
        (uint256 collateral, uint256 debt, , , , ) = IPool(AAVE_POOL)
            .getUserAccountData(address(this));
        return collateral > 0 ? (debt * PRECISION) / collateral : 0;
    }

    function getHealthFactor() external view returns (uint256) {
        (, , , , , uint256 hf) = IPool(AAVE_POOL).getUserAccountData(
            address(this)
        );
        return hf;
    }

    function needsMoreLoops(address user) external view returns (bool) {
        Position memory pos = positions[user];
        if (!pos.isActive || !pos.isLooping) return false;
        return
            pos.currentLTV < targetLTV && pos.loopsCompleted < absoluteMaxLoops;
    }

    receive() external payable {}
}
