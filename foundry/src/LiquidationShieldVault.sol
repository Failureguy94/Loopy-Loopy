// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract LiquidationShieldVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Sepolia Addresses
    address public constant AAVE_POOL =
        0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address public constant UNISWAP_ROUTER =
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;

    // Protection parameters
    uint256 public constant HEALTH_FACTOR_PRECISION = 1e18;
    uint256 public constant PROTECTION_THRESHOLD = 12e17; // 1.2 health factor triggers protection
    uint256 public constant SAFE_HEALTH_FACTOR = 15e17; // 1.5 health factor target after protection

    // Callback proxy address (set by Reactive Network)
    address public callbackProxy;

    // User position tracking
    struct Position {
        uint256 collateralAmount; // WETH collateral supplied
        uint256 debtAmount; // USDC borrowed
        uint256 protectionReserve; // ETH reserved for protection
        bool isActive;
        uint256 lastHealthFactor;
    }

    mapping(address => Position) public positions;

    // Events for Reactive Network to subscribe to
    event PositionCreated(
        address indexed user,
        uint256 collateralAmount,
        uint256 debtAmount,
        uint256 healthFactor
    );

    event HealthFactorUpdated(
        address indexed user,
        uint256 healthFactor,
        uint256 timestamp
    );

    event ProtectionTriggered(
        address indexed user,
        uint256 debtRepaid,
        uint256 newHealthFactor
    );

    event PositionClosed(address indexed user, uint256 amountReturned);

    constructor(address _callbackProxy) Ownable(msg.sender) {
        callbackProxy = _callbackProxy;
    }

    /// @notice Modifier to restrict calls to callback proxy only
    modifier onlyCallbackProxy() {
        require(msg.sender == callbackProxy, "Only callback proxy");
        _;
    }

    /// @notice Update callback proxy address
    function setCallbackProxy(address _callbackProxy) external onlyOwner {
        callbackProxy = _callbackProxy;
    }

    /// @notice Create a leveraged position with liquidation protection
    /// @dev User deposits ETH, 80% goes to Aave as collateral, 20% reserved for protection
    function createPosition() external payable nonReentrant {
        require(msg.value >= 0.01 ether, "Minimum 0.01 ETH");
        require(!positions[msg.sender].isActive, "Position already exists");

        uint256 totalDeposit = msg.value;
        uint256 protectionReserve = (totalDeposit * 20) / 100; // 20% for protection
        uint256 collateralAmount = totalDeposit - protectionReserve;

        // Wrap ETH to WETH
        IWETH(WETH).deposit{value: collateralAmount}();

        // Approve and supply to Aave
        IERC20(WETH).approve(AAVE_POOL, collateralAmount);
        IPool(AAVE_POOL).supply(WETH, collateralAmount, address(this), 0);

        // Borrow USDC (50% of max borrowing capacity for safety)
        (, , uint256 availableBorrows, , , ) = IPool(AAVE_POOL)
            .getUserAccountData(address(this));
        uint256 borrowAmount = (availableBorrows * 50) / 100;

        if (borrowAmount > 0) {
            IPool(AAVE_POOL).borrow(USDC, borrowAmount, 2, 0, address(this));
        }

        // Get current health factor
        (, , , , , uint256 healthFactor) = IPool(AAVE_POOL).getUserAccountData(
            address(this)
        );

        // Store position
        positions[msg.sender] = Position({
            collateralAmount: collateralAmount,
            debtAmount: borrowAmount,
            protectionReserve: protectionReserve,
            isActive: true,
            lastHealthFactor: healthFactor
        });

        emit PositionCreated(
            msg.sender,
            collateralAmount,
            borrowAmount,
            healthFactor
        );
        emit HealthFactorUpdated(msg.sender, healthFactor, block.timestamp);
    }

    /// @notice Update and emit health factor for monitoring
    /// @dev Can be called by anyone to update position health
    function updateHealthFactor(address user) external {
        require(positions[user].isActive, "No active position");

        (, , , , , uint256 healthFactor) = IPool(AAVE_POOL).getUserAccountData(
            address(this)
        );
        positions[user].lastHealthFactor = healthFactor;

        emit HealthFactorUpdated(user, healthFactor, block.timestamp);
    }

    /// @notice Execute protection when health factor is low
    /// @dev Called by ProtectionExecutor via Reactive Network callback
    function triggerProtection(
        address user
    ) external onlyCallbackProxy nonReentrant {
        Position storage pos = positions[user];
        require(pos.isActive, "No active position");

        (, , , , , uint256 healthFactor) = IPool(AAVE_POOL).getUserAccountData(
            address(this)
        );
        require(
            healthFactor < PROTECTION_THRESHOLD,
            "Health factor still safe"
        );

        // Use protection reserve to repay debt
        uint256 reserveToUse = pos.protectionReserve;
        require(reserveToUse > 0, "No protection reserve");

        // Wrap reserve ETH to WETH
        IWETH(WETH).deposit{value: reserveToUse}();

        // Swap WETH to USDC for debt repayment
        IERC20(WETH).approve(UNISWAP_ROUTER, reserveToUse);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: USDC,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: reserveToUse,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 usdcReceived = ISwapRouter(UNISWAP_ROUTER).exactInputSingle(
            params
        );

        // Repay debt
        IERC20(USDC).approve(AAVE_POOL, usdcReceived);
        IPool(AAVE_POOL).repay(USDC, usdcReceived, 2, address(this));

        // Update position
        pos.protectionReserve = 0;
        pos.debtAmount = pos.debtAmount > usdcReceived
            ? pos.debtAmount - usdcReceived
            : 0;

        // Get new health factor
        (, , , , , uint256 newHealthFactor) = IPool(AAVE_POOL)
            .getUserAccountData(address(this));
        pos.lastHealthFactor = newHealthFactor;

        emit ProtectionTriggered(user, usdcReceived, newHealthFactor);
        emit HealthFactorUpdated(user, newHealthFactor, block.timestamp);
    }

    /// @notice Close position and withdraw funds
    function closePosition() external nonReentrant {
        Position storage pos = positions[msg.sender];
        require(pos.isActive, "No active position");

        // Repay all debt first (user must have USDC)
        if (pos.debtAmount > 0) {
            uint256 debtToRepay = pos.debtAmount;
            IERC20(USDC).safeTransferFrom(
                msg.sender,
                address(this),
                debtToRepay
            );
            IERC20(USDC).approve(AAVE_POOL, debtToRepay);
            IPool(AAVE_POOL).repay(USDC, debtToRepay, 2, address(this));
        }

        // Withdraw collateral
        uint256 collateral = pos.collateralAmount;
        IPool(AAVE_POOL).withdraw(WETH, collateral, address(this));

        // Unwrap WETH
        IWETH(WETH).withdraw(collateral);

        // Return funds
        uint256 totalReturn = collateral + pos.protectionReserve;
        pos.isActive = false;
        pos.collateralAmount = 0;
        pos.debtAmount = 0;
        pos.protectionReserve = 0;

        (bool success, ) = msg.sender.call{value: totalReturn}("");
        require(success, "ETH transfer failed");

        emit PositionClosed(msg.sender, totalReturn);
    }

    /// @notice Get current health factor for a user
    function getHealthFactor() external view returns (uint256) {
        (, , , , , uint256 healthFactor) = IPool(AAVE_POOL).getUserAccountData(
            address(this)
        );
        return healthFactor;
    }

    /// @notice Get position details
    function getPosition(address user) external view returns (Position memory) {
        return positions[user];
    }

    /// @notice Check if protection is needed
    function needsProtection(address user) external view returns (bool) {
        if (!positions[user].isActive) return false;
        (, , , , , uint256 healthFactor) = IPool(AAVE_POOL).getUserAccountData(
            address(this)
        );
        return healthFactor < PROTECTION_THRESHOLD;
    }

    receive() external payable {}
}
