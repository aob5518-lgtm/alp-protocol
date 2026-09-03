// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPriceOracleAdapter} from "./interfaces/IPriceOracleAdapter.sol";
import {IPancakeV2Router} from "./interfaces/IPancakeV2Router.sol";
import {IProtocolController} from "./interfaces/IProtocolController.sol";

/// @notice Timelocked, oracle-guarded executor for the 5% asset-buyback treasury.
contract BuybackExecutor is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error RouterNotWhitelisted(address router);
    error TokenNotWhitelisted(address token);
    error InvalidPath();
    error InvalidAmount();
    error TradeTooLarge(uint256 amount, uint256 maximum);
    error InvalidSlippage(uint16 slippageBps);
    error TradeNotQueued(bytes32 tradeId);
    error TradeAlreadyQueued(bytes32 tradeId);
    error TradeAlreadyExecuted(bytes32 tradeId);
    error TradeNotReady(bytes32 tradeId, uint256 executableAt, uint256 currentTime);
    error PriceUnavailable(address token);
    error InsufficientMinimumOut(uint256 minimumOut, uint256 oracleMinimumOut);
    error RouterOutputTooLow(uint256 actualOut, uint256 minimumOut);

    bytes32 public constant SCHEDULER_ROLE = keccak256("SCHEDULER_ROLE");
    uint16 public constant BPS_DENOMINATOR = 10_000;

    struct QueuedTrade {
        address router;
        address tokenIn;
        address tokenOut;
        uint128 amountIn;
        uint64 executableAt;
        bool executed;
    }

    IERC20 public immutable paymentToken;
    address public immutable buybackTreasury;
    IPriceOracleAdapter public immutable oracle;
    IProtocolController public immutable protocolController;
    address public buybackRecipient;
    uint64 public immutable executionDelay;
    uint16 public maxSlippageBps;
    mapping(address => bool) public routerWhitelist;
    mapping(address => uint256) public maxTradeAmount;
    mapping(address => bool) public tokenWhitelist;
    mapping(bytes32 => QueuedTrade) public queuedTrade;
    mapping(bytes32 => address[]) private _queuedPaths;

    event RouterWhitelistUpdated(address indexed router, bool allowed);
    event TokenConfigured(address indexed token, bool allowed, uint256 maxTradeAmount);
    event BuybackRecipientUpdated(address indexed recipient);
    event MaxSlippageUpdated(uint16 maxSlippageBps);
    event TradeQueued(
        bytes32 indexed tradeId,
        address indexed router,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 executableAt
    );
    event BuybackExecuted(
        bytes32 indexed tradeId,
        address indexed router,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(
        IERC20 paymentToken_,
        address buybackTreasury_,
        IPriceOracleAdapter oracle_,
        address buybackRecipient_,
        uint64 executionDelay_,
        uint16 maxSlippageBps_,
        IProtocolController protocolController_,
        address admin
    ) {
        if (
            address(paymentToken_) == address(0) || buybackTreasury_ == address(0) || address(oracle_) == address(0)
                || buybackRecipient_ == address(0) || admin == address(0)
                || address(protocolController_) == address(0)
        ) revert ZeroAddress();
        if (maxSlippageBps_ >= BPS_DENOMINATOR) revert InvalidSlippage(maxSlippageBps_);
        paymentToken = paymentToken_;
        buybackTreasury = buybackTreasury_;
        oracle = oracle_;
        protocolController = protocolController_;
        buybackRecipient = buybackRecipient_;
        executionDelay = executionDelay_;
        maxSlippageBps = maxSlippageBps_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setRouterWhitelist(address router, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (router == address(0)) revert ZeroAddress();
        routerWhitelist[router] = allowed;
        emit RouterWhitelistUpdated(router, allowed);
    }

    function configureToken(address token, bool allowed, uint256 maximumTradeAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (allowed && maximumTradeAmount == 0) revert InvalidAmount();
        tokenWhitelist[token] = allowed;
        maxTradeAmount[token] = maximumTradeAmount;
        emit TokenConfigured(token, allowed, maximumTradeAmount);
    }

    function setBuybackRecipient(address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert ZeroAddress();
        buybackRecipient = recipient;
        emit BuybackRecipientUpdated(recipient);
    }

    function setMaxSlippageBps(uint16 slippageBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (slippageBps >= BPS_DENOMINATOR) revert InvalidSlippage(slippageBps);
        maxSlippageBps = slippageBps;
        emit MaxSlippageUpdated(slippageBps);
    }

    function queueTrade(address router, address tokenIn, address tokenOut, uint128 amountIn)
        external
        onlyRole(SCHEDULER_ROLE)
        returns (bytes32 tradeId)
    {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return _queueTrade(router, path, amountIn);
    }

    /// @notice Queues a whitelisted Pancake V2 path. Every asset in the path has an
    /// independent live oracle check at execution, so intermediate hops are not trusted.
    function queueTradePath(address router, address[] calldata path, uint128 amountIn)
        external
        onlyRole(SCHEDULER_ROLE)
        returns (bytes32 tradeId)
    {
        address[] memory copiedPath = path;
        return _queueTrade(router, copiedPath, amountIn);
    }

    function queuedPath(bytes32 tradeId) external view returns (address[] memory) {
        return _queuedPaths[tradeId];
    }

    function _queueTrade(address router, address[] memory path, uint128 amountIn) private returns (bytes32 tradeId) {
        _validateTrade(router, path, amountIn);
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];
        tradeId = keccak256(abi.encode(router, path, amountIn, block.chainid, block.timestamp));
        if (queuedTrade[tradeId].executableAt != 0) revert TradeAlreadyQueued(tradeId);
        uint64 executableAt = uint64(block.timestamp) + executionDelay;
        queuedTrade[tradeId] = QueuedTrade({
            router: router,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            executableAt: executableAt,
            executed: false
        });
        _queuedPaths[tradeId] = path;
        emit TradeQueued(tradeId, router, tokenIn, tokenOut, amountIn, executableAt);
    }

    /// @param minimumOut User/keeper supplied bound; it must be no worse than the live oracle bound.
    function executeTrade(bytes32 tradeId, uint256 minimumOut, uint256 deadline) external nonReentrant returns (uint256 amountOut) {
        protocolController.requireOperational();
        QueuedTrade storage trade = queuedTrade[tradeId];
        if (trade.executableAt == 0) revert TradeNotQueued(tradeId);
        if (trade.executed) revert TradeAlreadyExecuted(tradeId);
        if (block.timestamp < trade.executableAt) revert TradeNotReady(tradeId, trade.executableAt, block.timestamp);
        address[] memory path = _queuedPaths[tradeId];
        _validateTrade(trade.router, path, trade.amountIn);
        uint256 liveOracleMinimumOut = _oracleMinimumOutPath(path, trade.amountIn);
        if (minimumOut < liveOracleMinimumOut) revert InsufficientMinimumOut(minimumOut, liveOracleMinimumOut);

        trade.executed = true;
        IERC20 inputToken = IERC20(trade.tokenIn);
        inputToken.safeTransferFrom(buybackTreasury, address(this), trade.amountIn);
        inputToken.forceApprove(trade.router, trade.amountIn);
        uint256[] memory amounts = IPancakeV2Router(trade.router).swapExactTokensForTokens(
            trade.amountIn, minimumOut, path, buybackRecipient, deadline
        );
        amountOut = amounts[amounts.length - 1];
        if (amountOut < minimumOut) revert RouterOutputTooLow(amountOut, minimumOut);
        inputToken.forceApprove(trade.router, 0);
        emit BuybackExecuted(tradeId, trade.router, trade.tokenIn, trade.tokenOut, trade.amountIn, amountOut);
    }

    function oracleMinimumOut(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return _oracleMinimumOutPath(path, amountIn);
    }

    function oracleMinimumOutPath(address[] calldata path, uint256 amountIn) external view returns (uint256) {
        address[] memory copiedPath = path;
        return _oracleMinimumOutPath(copiedPath, amountIn);
    }

    function _oracleMinimumOutPath(address[] memory path, uint256 amountIn) private view returns (uint256) {
        if (path.length < 2) revert InvalidPath();
        uint256 amount = amountIn;
        for (uint256 i; i < path.length - 1; ++i) {
            address tokenIn = path[i];
            address tokenOut = path[i + 1];
            if (tokenIn == tokenOut || !oracle.isPriceValid(tokenIn)) revert PriceUnavailable(tokenIn);
            if (!oracle.isPriceValid(tokenOut)) revert PriceUnavailable(tokenOut);
            (uint256 priceIn,) = oracle.getPrice(tokenIn);
            (uint256 priceOut,) = oracle.getPrice(tokenOut);
            if (priceIn == 0) revert PriceUnavailable(tokenIn);
            if (priceOut == 0) revert PriceUnavailable(tokenOut);
            uint256 amountInWad = amount * 1e18 / (10 ** IERC20Metadata(tokenIn).decimals());
            uint256 expectedOutWad = amountInWad * priceIn / priceOut;
            amount = expectedOutWad * (10 ** IERC20Metadata(tokenOut).decimals()) / 1e18;
        }
        return amount * (BPS_DENOMINATOR - maxSlippageBps) / BPS_DENOMINATOR;
    }

    function _validateTrade(address router, address[] memory path, uint256 amountIn) private view {
        if (!routerWhitelist[router]) revert RouterNotWhitelisted(router);
        if (path.length < 2 || path[0] != address(paymentToken) || amountIn == 0) revert InvalidPath();
        for (uint256 i; i < path.length; ++i) {
            if (!tokenWhitelist[path[i]]) revert TokenNotWhitelisted(path[i]);
            if (i != 0 && path[i] == path[i - 1]) revert InvalidPath();
        }
        uint256 maximum = maxTradeAmount[path[0]];
        if (amountIn > maximum) revert TradeTooLarge(amountIn, maximum);
    }
}
