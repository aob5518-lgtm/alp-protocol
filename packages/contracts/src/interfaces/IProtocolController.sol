// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IProtocolController {
    function requireOperational() external view;
    function requireProductionReady() external view;
}
