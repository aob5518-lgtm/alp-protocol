// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ILiquidityCycleManager} from "./interfaces/ILiquidityCycleManager.sol";

/// @notice Fixed-supply ALP with a MainPair buy block and an immutable 17% sell fee schedule.
/// @dev Ownership is expected to be a timelock-controlled Safe before production activation.
contract ALPToken is ERC20, Ownable2Step, AccessControl {
    error ZeroAddress();
    error MainPairAlreadyConfigured();
    error ALPBuyRestricted(address buyer);
    error InvalidFeeConfiguration();
    error LiquidityCycleManagerAlreadyConfigured();
    error EmissionEngineAlreadyConfigured();
    error OnlyEmissionEngine(address caller);
    error OnlyLiquidityCycleManager(address caller);
    error GenesisReserveMustBeContract(address reserve);
    error OnlyGenesisReserve(address caller);
    error LiquidityBootstrapperAlreadyConfigured();
    error OnlyLiquidityBootstrapper(address caller);

    uint256 public constant MAX_SUPPLY = 210_000_000 ether;
    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint16 public constant SELL_FEE_BPS = 1_700;
    uint16 public constant BUYBACK_BPS = 500;
    uint16 public constant TOP100_BPS = 100;
    uint16 public constant NODE_AIRDROP_BPS = 400;
    uint16 public constant COMMUNITY_BPS = 500;
    uint16 public constant DEVELOPMENT_BPS = 200;
    address public mainPair;
    address public immutable genesisReserve;
    address public liquidityBootstrapper;
    address public emissionEngine;
    address public liquidityCycleManager;
    bool public buyRestrictionEnabled = true;
    mapping(address => bool) public buyWhitelist;
    mapping(address => bool) public sellFeeExempt;

    address public immutable assetBuybackTreasury;
    address public immutable top100Treasury;
    address public immutable nodeAirdropTreasury;
    address public immutable communityTreasury;
    address public immutable developmentTreasury;

    event MainPairConfigured(address indexed pair);
    event BuyWhitelistUpdated(address indexed account, bool allowed);
    event SellFeeExemptionUpdated(address indexed account, bool exempt);
    event BuyRestrictionUpdated(bool enabled);
    event SellFeeCollected(address indexed seller, uint256 grossAmount, uint256 feeAmount);
    event ProtocolBurned(address indexed account, uint256 amount, address indexed engine);
    event ProtocolTransferred(address indexed from, address indexed to, uint256 amount, address engine);
    event LiquidityCycleManagerConfigured(address indexed manager);
    event EmissionEngineConfigured(address indexed engine);
    event LiquidityBootstrapperConfigured(address indexed bootstrapper);

    constructor(
        address initialReserve,
        address initialOwner,
        address assetBuybackTreasury_,
        address top100Treasury_,
        address nodeAirdropTreasury_,
        address communityTreasury_,
        address developmentTreasury_
    ) ERC20("Asset Launch Protocol Token", "ALP") Ownable(initialOwner) {
        if (
            initialReserve == address(0) || initialOwner == address(0) || assetBuybackTreasury_ == address(0)
                || top100Treasury_ == address(0) || nodeAirdropTreasury_ == address(0)
                || communityTreasury_ == address(0) || developmentTreasury_ == address(0)
        ) revert ZeroAddress();
        if (initialReserve.code.length == 0) revert GenesisReserveMustBeContract(initialReserve);
        if (BUYBACK_BPS + TOP100_BPS + NODE_AIRDROP_BPS + COMMUNITY_BPS + DEVELOPMENT_BPS != SELL_FEE_BPS) {
            revert InvalidFeeConfiguration();
        }
        assetBuybackTreasury = assetBuybackTreasury_;
        top100Treasury = top100Treasury_;
        nodeAirdropTreasury = nodeAirdropTreasury_;
        communityTreasury = communityTreasury_;
        developmentTreasury = developmentTreasury_;
        genesisReserve = initialReserve;
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _mint(initialReserve, MAX_SUPPLY);
    }

    function configureMainPair(address pair) external onlyOwner {
        if (pair == address(0)) revert ZeroAddress();
        if (mainPair != address(0)) revert MainPairAlreadyConfigured();
        mainPair = pair;
        buyWhitelist[pair] = true;
        emit MainPairConfigured(pair);
        emit BuyWhitelistUpdated(pair, true);
    }

    function setBuyWhitelist(address account, bool allowed) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        buyWhitelist[account] = allowed;
        emit BuyWhitelistUpdated(account, allowed);
    }

    function setSellFeeExempt(address account, bool exempt) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        sellFeeExempt[account] = exempt;
        emit SellFeeExemptionUpdated(account, exempt);
    }

    function setBuyRestrictionEnabled(bool enabled) external onlyOwner {
        buyRestrictionEnabled = enabled;
        emit BuyRestrictionUpdated(enabled);
    }

    function configureLiquidityCycleManager(address manager) external onlyOwner {
        if (manager == address(0)) revert ZeroAddress();
        if (liquidityCycleManager != address(0)) revert LiquidityCycleManagerAlreadyConfigured();
        liquidityCycleManager = manager;
        emit LiquidityCycleManagerConfigured(manager);
    }

    function configureEmissionEngine(address engine) external onlyOwner {
        if (engine == address(0)) revert ZeroAddress();
        if (emissionEngine != address(0)) revert EmissionEngineAlreadyConfigured();
        emissionEngine = engine;
        emit EmissionEngineConfigured(engine);
    }

    function configureLiquidityBootstrapper(address bootstrapper) external onlyOwner {
        if (bootstrapper == address(0)) revert ZeroAddress();
        if (liquidityBootstrapper != address(0)) revert LiquidityBootstrapperAlreadyConfigured();
        liquidityBootstrapper = bootstrapper;
        emit LiquidityBootstrapperConfigured(bootstrapper);
    }

    function configureMainPairFromBootstrapper(address pair) external {
        if (msg.sender != liquidityBootstrapper) revert OnlyLiquidityBootstrapper(msg.sender);
        if (pair == address(0)) revert ZeroAddress();
        if (mainPair != address(0)) revert MainPairAlreadyConfigured();
        mainPair = pair;
        buyWhitelist[pair] = true;
        emit MainPairConfigured(pair);
        emit BuyWhitelistUpdated(pair, true);
    }

    function burnFromMainPair(uint256 amount) external {
        if (msg.sender != emissionEngine) revert OnlyEmissionEngine(msg.sender);
        _burn(mainPair, amount);
        emit ProtocolBurned(mainPair, amount, msg.sender);
    }

    function transferEmission(address recipient, uint256 amount) external {
        if (msg.sender != emissionEngine) revert OnlyEmissionEngine(msg.sender);
        if (recipient == address(0)) revert ZeroAddress();
        super._update(mainPair, recipient, amount);
        emit ProtocolTransferred(mainPair, recipient, amount, msg.sender);
    }

    function forceBurnForLiquidityCycle(address account, uint256 amount) external {
        if (msg.sender != liquidityCycleManager) revert OnlyLiquidityCycleManager(msg.sender);
        _burn(account, amount);
        emit ProtocolBurned(account, amount, msg.sender);
    }

    function burnFromGenesisReserve(uint256 amount) external {
        if (msg.sender != genesisReserve) revert OnlyGenesisReserve(msg.sender);
        _burn(genesisReserve, amount);
        emit ProtocolBurned(genesisReserve, amount, msg.sender);
    }

    function _update(address from, address to, uint256 value) internal override {
        address pair = mainPair;
        if (pair != address(0) && buyRestrictionEnabled && from == pair && to != address(0) && !buyWhitelist[to]) {
            revert ALPBuyRestricted(to);
        }
        if (pair != address(0) && to == pair && from != address(0) && !sellFeeExempt[from]) {
            uint256 buybackFee = value * BUYBACK_BPS / BPS_DENOMINATOR;
            uint256 top100Fee = value * TOP100_BPS / BPS_DENOMINATOR;
            uint256 nodeAirdropFee = value * NODE_AIRDROP_BPS / BPS_DENOMINATOR;
            uint256 communityFee = value * COMMUNITY_BPS / BPS_DENOMINATOR;
            uint256 developmentFee = value * DEVELOPMENT_BPS / BPS_DENOMINATOR;
            uint256 feeAmount = buybackFee + top100Fee + nodeAirdropFee + communityFee + developmentFee;
            super._update(from, assetBuybackTreasury, buybackFee);
            super._update(from, top100Treasury, top100Fee);
            super._update(from, nodeAirdropTreasury, nodeAirdropFee);
            super._update(from, communityTreasury, communityFee);
            super._update(from, developmentTreasury, developmentFee);
            super._update(from, to, value - feeAmount);
            if (liquidityCycleManager != address(0)) ILiquidityCycleManager(liquidityCycleManager).onAlpSold(from, value);
            emit SellFeeCollected(from, value, feeAmount);
            return;
        }
        // Ordinary wallet-to-wallet movement must preserve the sender's active
        // liquidity-cycle reserve. Pair sells are handled above and explicitly
        // credited as valid cycle activity; configured protocol transfers use
        // their narrow dedicated entry points instead of this path.
        if (
            liquidityCycleManager != address(0) && from != address(0) && to != address(0) && from != pair && to != pair
        ) {
            ILiquidityCycleManager(liquidityCycleManager).beforeAlpTransfer(from, to, value);
        }
        super._update(from, to, value);
        if (liquidityCycleManager != address(0) && from != address(0) && to != address(0)) {
            ILiquidityCycleManager(liquidityCycleManager).onAlpReceived(to, value);
        }
    }
}
