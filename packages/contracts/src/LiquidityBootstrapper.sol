// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ALPToken} from "./ALPToken.sol";
import {ILiquidityALPSource} from "./interfaces/ILiquidityALPSource.sol";
import {IPancakeV2Router} from "./interfaces/IPancakeV2Router.sol";
import {IPancakeV2Factory} from "./interfaces/IPancakeV2Factory.sol";
import {PermanentLiquidityLocker} from "./PermanentLiquidityLocker.sol";

/// @notice One-time ALP/USDT pair initialization at the fixed V1 target price.
contract LiquidityBootstrapper is Ownable2Step {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error AlreadyInitialized();
    error PriceRatioMismatch(uint256 suppliedUsdt, uint256 requiredUsdt);

    uint256 public constant TARGET_PRICE_E18 = 0.0001 ether;

    ALPToken public immutable alp;
    IERC20Metadata public immutable usdt;
    ILiquidityALPSource public immutable source;
    IPancakeV2Router public immutable router;
    IPancakeV2Factory public immutable factory;
    PermanentLiquidityLocker public immutable locker;
    bool public initialized;
    address public mainPair;

    event LiquidityBootstrapped(
        address indexed pair,
        uint256 initialAlpReserve,
        uint256 initialUsdtReserve,
        uint256 lpAmount,
        uint256 initialPriceE18,
        address indexed lpBurnAddress
    );

    constructor(
        ALPToken alp_,
        IERC20Metadata usdt_,
        ILiquidityALPSource source_,
        IPancakeV2Router router_,
        IPancakeV2Factory factory_,
        PermanentLiquidityLocker locker_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            address(alp_) == address(0) || address(usdt_) == address(0) || address(source_) == address(0)
                || address(router_) == address(0) || address(factory_) == address(0) || address(locker_) == address(0)
                || initialOwner == address(0)
        ) revert ZeroAddress();
        alp = alp_;
        usdt = usdt_;
        source = source_;
        router = router_;
        factory = factory_;
        locker = locker_;
    }

    function requiredUsdtForAlp(uint256 alpAmount) public view returns (uint256) {
        uint256 valueWad = alpAmount * TARGET_PRICE_E18 / (10 ** alp.decimals());
        return valueWad * (10 ** usdt.decimals()) / 1e18;
    }

    function initialize(uint256 alpAmount, uint256 usdtAmount, uint256 minAlpAmount, uint256 minUsdtAmount, uint256 deadline)
        external
        onlyOwner
        returns (address pair, uint256 usedAlp, uint256 usedUsdt, uint256 lpAmount)
    {
        if (initialized) revert AlreadyInitialized();
        uint256 requiredUsdt = requiredUsdtForAlp(alpAmount);
        if (usdtAmount != requiredUsdt) revert PriceRatioMismatch(usdtAmount, requiredUsdt);
        pair = factory.getPair(address(alp), address(usdt));
        if (pair == address(0)) pair = factory.createPair(address(alp), address(usdt));
        bytes32 operation = keccak256(abi.encodePacked("BOOTSTRAP", block.chainid, alpAmount, usdtAmount));
        source.provideLiquidityALP(address(this), alpAmount, operation);
        IERC20(address(alp)).forceApprove(address(router), alpAmount);
        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);
        usdt.forceApprove(address(router), usdtAmount);
        (usedAlp, usedUsdt, lpAmount) = router.addLiquidity(
            address(alp), address(usdt), alpAmount, usdtAmount, minAlpAmount, minUsdtAmount, address(locker), deadline
        );
        uint256 requiredUsedUsdt = requiredUsdtForAlp(usedAlp);
        if (usedAlp == 0 || usedUsdt != requiredUsedUsdt) {
            revert PriceRatioMismatch(usedUsdt, requiredUsedUsdt);
        }
        IERC20(address(alp)).forceApprove(address(router), 0);
        usdt.forceApprove(address(router), 0);
        locker.recordLock(pair, lpAmount, operation);
        alp.configureMainPairFromBootstrapper(pair);
        initialized = true;
        mainPair = pair;
        emit LiquidityBootstrapped(pair, usedAlp, usedUsdt, lpAmount, TARGET_PRICE_E18, address(locker));
    }
}
