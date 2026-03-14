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

    // Function to create a new campaign
    function createCampaign(string memory _title, string memory _description, uint256 _goalAmount, uint256 _deadline) external {

        // Perform checks
        require(bytes(_title).length > 0, "Title cannot be empty.");
        require(bytes(_title).length <= 100, "Title is too long.");
        require(bytes(_description).length > 0, "Description cannot be empty.");
        require(bytes(_description).length <= 500, "Description is too long.");
        require(_goalAmount > 0.1 ether, "Goal amount must be greater than 0.1 ETH.");
        require(_deadline > block.timestamp, "Deadline must be in the future.");

        // Create id
        campaignIdCounter += 1;

        // Create new campaign
        Campaign memory newCampaign = Campaign({
            id: campaignIdCounter,
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            totalPledged: 0,
            deadline: _deadline,
            status: Status.Active,
            creator: msg.sender,
            fundsWithdrawn: false,
            isFinalised: false
        });

        // Save to mapping
        campaigns[campaignIdCounter] = newCampaign;

        // Emit event
        emit NewCampaign(campaignIdCounter);
    }

    // Function to pledge to a campaign
    function pledge(uint256 _campaignId) external payable {

        // Perform checks
        require(campaigns[_campaignId].status == Status.Active, "Campaign has been finalised or cancelled.");
        require(msg.value > 0 ether, "Pledge amount cannot be less than 0 ETH.");

        // Save pledged amount by backer
        pledges[_campaignId][msg.sender] += msg.value;

        // Add up the amount to the campaign
        campaigns[_campaignId].totalPledged += msg.value;

        // Emit event
        emit NewPledge(_campaignId, msg.value);
    }

    // Function to finalise campaign
    function finaliseCampaign(uint256 _campaignId) external {

        // Perform checks
        require(block.timestamp > campaigns[_campaignId].deadline, "Deadline not reached yet.");
        require(campaigns[_campaignId].isFinalised == false, "Campaign has already been finalised.");

        // Check if campaign has reached goal
        if (campaigns[_campaignId].totalPledged >= campaigns[_campaignId].goalAmount){
            campaigns[_campaignId].status = Status.Successful;
        } else if (campaigns[_campaignId].totalPledged < campaigns[_campaignId].goalAmount) {
            campaigns[_campaignId].status = Status.Failed;
        }

        // Change to finalised
        campaigns[_campaignId].isFinalised = true;

        // Emit event
        emit CampaignFinalised(_campaignId);
    }

    // Function to distribute funds
    function distributeFunds(uint256 _campaignId) external {

        // Perform checks
        require(campaigns[_campaignId].status == Status.Successful || campaigns[_campaignId].status == Status.Failed, "Campaign is cancelled or still open.");
        require(campaigns[_campaignId].isFinalised == true, "Campaign has not been finalised yet.");

        // Creator withdraw & owner payout
        if (campaigns[_campaignId].status == Status.Successful){
            require(msg.sender == campaigns[_campaignId].creator, "Only creator can withdraw");
            require(!campaigns[_campaignId].fundsWithdrawn, "Funds already withdrawn");

            uint256 platformFee = (campaigns[_campaignId].totalPledged * 3) / 100;
            uint256 creatorFee = campaigns[_campaignId].totalPledged - platformFee;

            campaigns[_campaignId].fundsWithdrawn = true;

            (bool ownerPayout, ) = payable(owner).call{value: platformFee}('');
            require(ownerPayout, "ETH not transferred to creator.");    

            (bool creatorPayout, ) = payable(campaigns[_campaignId].creator).call{value: creatorFee}('');
            require(creatorPayout, "ETH not transferred to creator.");
        }

        // Backer witdraw
        if (campaigns[_campaignId].status == Status.Failed){
            require(pledges[_campaignId][msg.sender] != 0, "You have already got everything back.");
            uint256 pledgeAmount = pledges[_campaignId][msg.sender];

            pledges[_campaignId][msg.sender] = 0; 

            (bool success, ) = payable(msg.sender).call{value: pledgeAmount}('');
            require(success, "ETH not transferred to backer.");
        }

        // Emit event
        emit FundsDistributed(_campaignId);
    }

    // Function to cancel a campaign
    function cancelCampaign(uint256 _campaignId) external OnlyCreator(_campaignId){

        // Perform checks
        require(campaigns[_campaignId].deadline > block.timestamp, "Can't cancel after the deadline.");
        require(campaigns[_campaignId].status == Status.Active, "Campaign already finalised.");

        // Change status to cancelled
        campaigns[_campaignId].status = Status.Cancelled;

        // Change isFinalised to true
        campaigns[_campaignId].isFinalised = true;

        // Emit event
        emit CancelledCampaign(_campaignId);
    }

    // Helper function to refund the backer
    function refundBacker(uint256 _campaignId) private {

        // Calculate amount to refund
        uint256 refundAmount = pledges[_campaignId][msg.sender];

        // Reset before refunding
        pledges[_campaignId][msg.sender] = 0;

        // Take away the withdrawn amount from total
        campaigns[_campaignId].totalPledged -= refundAmount;

        // Refund amount
        (bool success, ) = payable(msg.sender).call{value: refundAmount}('');
        require(success, "ETH not transferred to backer correctly.");

        // Emit event
        emit RefundIssued(_campaignId, refundAmount);
    }

    // Function to allow backers to claim their money from cancelled campaigns
    function claimPledge(uint256 _campaignId) external {

        // Perform checks
        require(campaigns[_campaignId].status == Status.Cancelled, "Campaign is not cancelled.");
        require(pledges[_campaignId][msg.sender] != 0, "You have no money to get back from this campaign.");

        // Refund amount
        refundBacker(_campaignId);
    }

    // Function to allow backers to withdraw their pledge
    function withdrawPledge(uint256 _campaignId) external {

        // Perform checks
        require(block.timestamp < campaigns[_campaignId].deadline, "Cannot withdraw after deadline.");
        require(pledges[_campaignId][msg.sender] != 0, "Cannot withdraw from a campaign you haven't backed.");
        require(campaigns[_campaignId].status == Status.Active, "Campaign has been finalised or cancelled.");

        // Refund the backer
        refundBacker(_campaignId);
    }
}