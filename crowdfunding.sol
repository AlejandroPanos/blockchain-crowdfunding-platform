// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {

    // Constructor
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // Initial declarations
    uint256 campaignIdCounter = 0;
    struct Campaign {
        uint256 id;
        string title;
        string description;
        uint256 goalAmount;
        uint256 totalPledged;
        uint256 deadline;
        Status status;
        address creator;
        bool fundsWithdrawn;
        bool isFinalised;
    }

    enum Status {
        Active,
        Successful,
        Failed, 
        Cancelled
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public pledges;

    // Modifier
    modifier OnlyCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "You are not the creator of the campaign.");
        _;
    }

    // Events
    event NewCampaign(uint256);
    event NewPledge(uint256, uint256);
    event CampaignFinalised(uint256);
    event FundsDistributed(uint256);
    event CancelledCampaign(uint256);
    event RefundIssued(uint256, uint256);
}