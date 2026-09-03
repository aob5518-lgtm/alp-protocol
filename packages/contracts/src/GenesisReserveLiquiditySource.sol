// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { GenesisReserve } from "./GenesisReserve.sol";
import { ILiquidityALPSource } from "./interfaces/ILiquidityALPSource.sol";

/// @notice Default testnet ALP source. It moves pre-minted ALP from GenesisReserve
/// only to explicitly configured liquidity consumers such as the manager or
/// one-time bootstrapper.
contract GenesisReserveLiquiditySource is AccessControl, ILiquidityALPSource {
    error ZeroAddress();
    error OnlyLiquidityConsumer(address caller);

    GenesisReserve public immutable genesisReserve;
    mapping(address => bool) public liquidityConsumer;

    event LiquidityConsumerUpdated(address indexed consumer, bool allowed);
    event LiquidityALPProvided(
        address indexed recipient, uint256 amount, bytes32 indexed operation
    );

    constructor(GenesisReserve genesisReserve_, address admin) {
        if (address(genesisReserve_) == address(0) || admin == address(0)) revert ZeroAddress();
        genesisReserve = genesisReserve_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setLiquidityConsumer(address consumer, bool allowed)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (consumer == address(0)) revert ZeroAddress();
        liquidityConsumer[consumer] = allowed;
        emit LiquidityConsumerUpdated(consumer, allowed);
    }

    function provideLiquidityALP(address recipient, uint256 amount, bytes32 operation) external {
        if (!liquidityConsumer[msg.sender]) revert OnlyLiquidityConsumer(msg.sender);
        if (recipient != msg.sender) revert OnlyLiquidityConsumer(recipient);
        genesisReserve.releaseToProtocol(recipient, amount, operation);
        emit LiquidityALPProvided(recipient, amount, operation);
    }
}
