// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISharedInterfaces.sol";

contract OriginLooper {
    address public constant AAVE_POOL =
        0x6aE9784f96A58aAf26C31D9d445c7553f146F259;
    address public constant UNISWAP_ROUTER =
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    uint256 public constant TARGET_LTV = 7500;
    uint256 public constant MAX_LOOPS = 5;
    address public reactiveSender;
    event LoopRequested(address indexed user, uint256 amount);
    event LoopCompleted(uint256 finalLTV, uint256 iterations);

    constructor(address _reactiveSender) {
        reactiveSender = _reactiveSender;
    }

    function deposit() external payable {
        IWETH(WETH).deposit{value: msg.value}();
        IERC20(WETH).approve(AAVE_POOL, msg.value);
        IPool(AAVE_POOL).supply(WETH, msg.value, address(this), 0);
        emit LoopRequested(msg.sender, msg.value);
    }

    function executeStrategy(address user, uint256) external onlyReactive {
        uint256 iterations = 0;
        uint256 currentLTV = getLTV();
        while (currentLTV < TARGET_LTV && iterations < MAX_LOOPS) {
            (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE_POOL)
                .getUserAccountData(address(this));
            uint256 borrowAmount = (availableBorrowsBase * 50) / 100;
            if (borrowAmount == 0) break;
            IPool(AAVE_POOL).borrow(USDC, borrowAmount, 2, 0, address(this));
            IERC20(USDC).approve(UNISWAP_ROUTER, borrowAmount);
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: USDC,
                    tokenOut: WETH,
                    fee: 3000,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: borrowAmount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            uint256 wethReceived = ISwapRouter(UNISWAP_ROUTER).exactInputSingle(
                params
            );
            IERC20(WETH).approve(AAVE_POOL, wethReceived);
            IPool(AAVE_POOL).supply(WETH, wethReceived, address(this), 0);
            iterations++;
            currentLTV = getLTV();
        }
        emit LoopCompleted(currentLTV, iterations);
    }

    modifier onlyReactive() {
        require(
            msg.sender == reactiveSender || msg.sender == address(this),
            "Unauthorized"
        );
        _;
    }

    function getLTV() internal view returns (uint256) {
        (, , , , uint256 ltv, ) = IPool(AAVE_POOL).getUserAccountData(
            address(this)
        );
        return ltv;
    }
}
