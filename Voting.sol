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

    //addess mapping to voter allowed to vote (whitelist)
    mapping(address => Voter) public whitelistedAddresses;
    //proposal mappping
    mapping(uint => Proposal) public proposals;
    //incremental number to assign a unique id to a proposal
    uint private proposalId =0;
    //list description used to check if a proposal already exists
    string[] public proposalDescriptionList;


    //register voters
    function registerVoter(address _address) public onlyOwner {
        require(uint8(currentWorkflow) ==0,"Phase invalid - Voter registration is forbidden");
        require(_address !=address(0),"address invalid");
        require(_address !=owner(),"Admin cannot participate");
        require(!whitelistedAddresses[_address].isRegistered,"Address already registered");
        //create voter with init value
        Voter memory voter = Voter({isRegistered : true, hasVoted :false,votedProposalId : 0});
        whitelistedAddresses[_address] = voter;
        //send event
        emit VoterRegistered(_address);
    }

     //register proposals
    function registerProposal(string memory _description) public {
        require(uint8(currentWorkflow) ==1,"Phase invalid - Proposal registration is forbidden");
        require(msg.sender !=address(0),"address invalid");
        require(msg.sender !=owner(),"Owner cannot participate");
        require(whitelistedAddresses[msg.sender].isRegistered,"Address not registered (whitelisted)");
        require(!checkProposalExists(_description),"Proposal already exists");
        //create proposal with init value
        Proposal memory proposal = Proposal({description : _description, voteCount:0});
        proposals[proposalId] = proposal;
        //send event
        emit ProposalRegistered(proposalId);
        proposalId++;
        proposalDescriptionList.push(_description);
    }

    //register vote
    function Vote(uint _proposalId) public {
        require(uint8(currentWorkflow) ==3,"Phase invalid - Voting is forbidden");
        require(msg.sender !=address(0),"address invalid");
        require(msg.sender !=owner(),"Owner cannot participate");
        require(whitelistedAddresses[msg.sender].isRegistered,"Address not registered (whitelisted)");
        require(!whitelistedAddresses[msg.sender].hasVoted,"Address has already voted");
        require(_proposalId<= proposalId && proposalId >=0,"PropoalId doesn't exist");
        //mark voter hasVoted && register proposalId
        whitelistedAddresses[msg.sender].hasVoted =true;
        whitelistedAddresses[msg.sender].votedProposalId= _proposalId;
        //send event
        emit Voted(msg.sender,_proposalId);
        //increment vote count
        proposals[_proposalId].voteCount += 1;
    }


    //Get the winning proposal id when votes are closed
    function winningProposalId() public view returns (uint){
        require(uint8(currentWorkflow) ==5,"Phase invalid - Winner cannot be determined yet !");
        uint winnerVoteCount = 0;
        uint winningPropId =0;
        for (uint i=0; i<proposalId; i++) {
           if(proposals[i].voteCount >=0 ){
               winnerVoteCount = proposals[i].voteCount;
               winningPropId = i;
           }
        }
        return winningPropId;
    }

     //Get the proposal winner when votes are closed
    function getWinner () public view returns (Proposal memory){
        require(uint8(currentWorkflow) ==5,"Phase invalid - Winner cannot be determined yet !");
        return proposals[winningProposalId()];
    }

    function checkProposalExists(string memory _description) internal view returns (bool){
        for (uint i=0; i<proposalDescriptionList.length; i++) {
            if(keccak256(abi.encodePacked(proposalDescriptionList[i])) == keccak256(abi.encodePacked(_description))){
                return true;
            }
        }
        return false;
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

     function startVotesTalliedPhase() public onlyOwner{
        require(uint8(currentWorkflow) ==4,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
    }
     /*************************************************************/
}
