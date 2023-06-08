// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Dummy contract to show paymaster sinking money into a pit :)
contract Sink {
    function sink() public payable {}
}
