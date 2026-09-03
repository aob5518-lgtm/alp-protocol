// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { GenesisReserve } from "../../src/GenesisReserve.sol";

contract GenesisReserveModule {
    function release(GenesisReserve reserve, address recipient, uint256 amount, bytes32 operation)
        external
    {
        reserve.releaseToProtocol(recipient, amount, operation);
    }
}
