// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/a7818b49a481e867230d4fa49d106bd304c5d95d/contracts/access/Ownable.sol";

contract Voting is Ownable {
    //voter struct
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    //proposal struct
    struct Proposal {
        string description;
        uint256 voteCount;
    }

    //voting workflow
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //events
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
    //current workflow
    WorkflowStatus currentWorkflow;

    //list addess allowed to vote (whitelist)
    mapping(address => Voter) public whitelistedAddresses;
    //proposal list
    mapping(uint => Proposal) public proposals;
    //incremental number to assign a unique id to a proposal
    uint proposalId =0;


    //register voters
    function registerVoter(address _address) public onlyOwner {
        require(uint8(currentWorkflow) ==0,"Phase invalid - Voter registration is forbidden");
        require(_address !=address(0),"address invalid");
        require(_address !=msg.sender,"Admin cannot participate");
        require(!whitelistedAddresses[_address].isRegistered,"Address already registered");
        //create voter with init value
        Voter memory voter = Voter({isRegistered : true, hasVoted :false,votedProposalId : 0});
        whitelistedAddresses[_address] = voter;
        //send event
        emit VoterRegistered(_address);
    }

     //register voters
    function registerProposal(string memory _description) public onlyOwner {
        require(uint8(currentWorkflow) ==1,"Phase invalid - Proposal registration is forbidden");
        require(msg.sender !=address(0),"address invalid");
        require(msg.sender !=owner(),"Admin cannot participate");
        require(whitelistedAddresses[msg.sender].isRegistered,"Address not registered (whitelisted");
        //create voter with init value
        Proposal memory proposal = Proposal({description : _description, voteCount:0});
        proposals[proposalId] = proposal;
        //send event
        emit ProposalRegistered(proposalId);
        proposalId++;
    }


    //Get the winning proposal id when votes are closed
    function winningProposalId() public view returns (uint){

    }

     //Get the proposal winner when votes are closed
    function getWinner () public view returns (Proposal memory){

    }


    /******************* Workflow management********************/
    function startRegisterVoterPhase() public onlyOwner{
        require(uint8(currentWorkflow) <=0,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = WorkflowStatus.RegisteringVoters;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
    }

    
    function startProposalsRegistrationPhase() public onlyOwner{
        require(uint8(currentWorkflow) ==0,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
    }

    
    function endProposalsRegistrationPhase() public onlyOwner{
        require(uint8(currentWorkflow) ==1,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
    }

   
    function startVotingSessionPhase() public onlyOwner{
        require(uint8(currentWorkflow) ==2,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
    }

    function endVotingSessionPhase() public onlyOwner{
        require(uint8(currentWorkflow) ==3,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
    }
     /*************************************************************/
}
