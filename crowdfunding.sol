// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {

    // Constructor
    address public owner;

    constructor() {
        owner = msg.sender;
    }
}