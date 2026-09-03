// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";

/// @notice Read-only deployment guard. It intentionally broadcasts no transaction.
/// Run it before any BSC testnet deployment to reject missing dependencies and an
/// unexpected chain before a private key can be used by a deployment script.
contract BscTestnetPreflight is Script {
    error UnexpectedChain(uint256 actual, uint256 expected);
    error MissingContractCode(string name, address candidate);
    error ZeroAddress(string name);

    function run() external view {
        uint256 expectedChainId = vm.envOr("EXPECTED_CHAIN_ID", uint256(97));
        if (block.chainid != expectedChainId) {
            revert UnexpectedChain(block.chainid, expectedChainId);
        }

        _requireCode("USDT_ADDRESS", vm.envAddress("USDT_ADDRESS"));
        _requireCode("PANCAKE_V2_ROUTER", vm.envAddress("PANCAKE_V2_ROUTER"));
        _requireCode("PANCAKE_V2_FACTORY", vm.envAddress("PANCAKE_V2_FACTORY"));
        _requireCode("SAFE_ADDRESS", vm.envAddress("SAFE_ADDRESS"));
        _requireCode("TIMELOCK_ADDRESS", vm.envAddress("TIMELOCK_ADDRESS"));
    }

    function _requireCode(string memory name, address candidate) private view {
        if (candidate == address(0)) revert ZeroAddress(name);
        if (candidate.code.length == 0) revert MissingContractCode(name, candidate);
    }
}
