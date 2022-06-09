// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.14;

//get Ownable from openZeppelin github
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/********Voting contract************** 
This contract manage voting system by phase (call startNextPhase with uint):
RegisteringVoters => 0
ProposalsRegistrationStarted=>1
ProposalsRegistrationEnded=>2
VotingSessionStarted=>3
VotingSessionEnded=>4
VotesTallied=>5

Only owner of the contract can change the phase
Only owner can register new voting address

Registered address can create vote proposal
Registered address can vote

Anyone can check vote result on proposal and address vote.
Anyone can check winning proposal

When deploying the contract a "white vote" proposal is automatically created
If more than one proposal has same amount of vote no winner can be determined

When being in last voting phase, the owner can reset the voting processus and start with fresh new vote proposal
****************************************/
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
        RegisteringVoters, //0
        ProposalsRegistrationStarted,//1
        ProposalsRegistrationEnded,//2
        VotingSessionStarted,//3
        VotingSessionEnded,//4
        VotesTallied//5
    }

    //state variables
    //current workflow
    WorkflowStatus public currentWorkflow;
    //addess mapping to voter allowed to vote (whitelist)
    //set public to create automatic getter and people check list of voters
    mapping(address => Voter) public whitelistedAddresses;
    //proposal mappping
    //set public to create automatic getter and people check list of proposals
    mapping(uint => Proposal) public proposals;
    //mapping to help determine the winner. It contains nbVote=> number of proposals.
    //Eg : if two proposals has 4 vote count each the mapping will be 4 (votes)=>2 (proposals)
    mapping(uint => uint) nbProposalGroupByVoteCount;
    //incremental number to assign a unique id to a proposal
    uint private proposalId;
    //list description used to check if a proposal already exists
    string[] proposalDescriptionList;

    //Array for reset
    address[] addresses;
    uint[] voteCountGroupBy;

    //events
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    //constructor to register by default white vote proposal
    constructor(){
        createProposal("White vote");
    }

    //Modifier to check only registered address
    modifier onlyRegistered() { 
       require(whitelistedAddresses[msg.sender].isRegistered,"Address not registered (whitelisted)");
       _;
    }

    //register voters. We assume the owner cannot participate to stay impartial.
    //max list size is set to 100 to limit gas usage and potential rollback
    function registerVoter(address[] calldata _addresses) public onlyOwner {
        require(uint8(currentWorkflow) ==0,"Phase invalid - Voter registration is forbidden");
        require(_addresses.length >0,"Address list is empty");
        require(_addresses.length <=100,"Address over 100 voters.");
        for(uint i=0; i<_addresses.length ; i++){
            address addr =  _addresses[i];
            require(addr !=address(0),"address invalid");
            require(addr !=owner(),"Admin cannot participate");
            require(!whitelistedAddresses[addr].isRegistered,"Address already registered");
            //create voter with init value
            Voter memory voter = Voter({isRegistered : true, hasVoted :false, votedProposalId : 0});
            whitelistedAddresses[addr] = voter;
            addresses.push(addr);
            //send event
            emit VoterRegistered(addr);
        }   
    }

    //register proposals
    //owner address and address(0) are filtered because cannot be added as voter, means not registered
    function registerProposal(string calldata _description) public onlyRegistered {
        require(uint8(currentWorkflow)==1,"Phase invalid - Proposal registration is forbidden");
        require(!checkProposalExists(_description),"Proposal already exists");
        //create proposal with init value
        createProposal(_description);
    }

    //proposal creation
    function createProposal(string memory _description) internal {
        Proposal memory proposal = Proposal({description : _description, voteCount:0});
        proposals[proposalId] = proposal;
        //send event
        emit ProposalRegistered(proposalId);
        proposalId++;
        proposalDescriptionList.push(_description);
    }

    //register vote
    //owner address and address(0) are filtered because cannot be added as voter, means not registered
    function Vote(uint _proposalId) public onlyRegistered {
        require(uint8(currentWorkflow)==3,"Phase invalid - Voting is forbidden");
        require(!whitelistedAddresses[msg.sender].hasVoted,"Address has already voted");
        require(_proposalId< proposalId && proposalId >=0,"Proposal doesn't exist");
        //mark voter hasVoted && register proposalId
        whitelistedAddresses[msg.sender].hasVoted =true;
        whitelistedAddresses[msg.sender].votedProposalId= _proposalId;
        //increment vote count
        proposals[_proposalId].voteCount += 1;
        //send event
        emit Voted(msg.sender,_proposalId);
    }


    //Get the winning proposal id when votes are closed. Simple majority consensus (proposal with most vote win)
    function winningProposalId() internal view returns (uint winnerId, bool hasUniqueWinner) {
        require(uint8(currentWorkflow) ==5,"Phase invalid - Winner cannot be determined yet !");
        uint winnerVoteCount = 0;
        uint winnerProposalId;
        //do not check white vote proposal so start at index 1
        for (uint i=1; i<proposalId; i++) {
            uint currentVoteCount = proposals[i].voteCount;
            if(( currentVoteCount > winnerVoteCount)){
               winnerVoteCount = currentVoteCount;
               winnerProposalId =i;
           }
        }

        //check if only one proposal win, means only one with winnerVoteCount
        return (winnerProposalId,nbProposalGroupByVoteCount[winnerVoteCount]==1);
    }

    //Get the proposal winner when votes are closed
    function getWinner() public view returns (string memory) {
        require(uint8(currentWorkflow) ==5,"Phase invalid - Winner cannot be determined yet !");
        (uint winner,bool hasWinner) = winningProposalId();
        string memory voteResult = "no winner";
        if(hasWinner){
            voteResult=proposals[winner].description;
        }
        return voteResult;
    }

    //keccak usage to compare string values for proposal description. This should be manage in the frontend.
    //added here to validate the contract
    function checkProposalExists(string calldata _description) internal view returns (bool) {
        for (uint i=0; i<proposalDescriptionList.length; i++) {
            if(keccak256(abi.encodePacked(proposalDescriptionList[i])) == keccak256(abi.encodePacked(_description))){
                return true;
            }
        }
        return false;
    }

    //compute vote. Populate nbProposalGroupByVoteCount mapping to help determine if they is a winner
    //Eg : if two proposals has 4 vote count each the mapping will be 4 (votes)=>2 (proposals)
    function computeVote() internal {
        require(uint8(currentWorkflow) ==5,"Phase invalid - Winner cannot be determined yet !");
        //do not check white vote proposal so start at index 1
        for (uint i=1; i<proposalId; i++) {
           nbProposalGroupByVoteCount[proposals[i].voteCount]++;
           voteCountGroupBy.push(proposals[i].voteCount);
        }
    }

    /*******************RESET***********************/
    //Reset data, can only be called on the last phase to not interrupt the current vote phase
    function reset() public onlyOwner {
        require(uint8(currentWorkflow) ==5,"Phase invalid - Reset can only be done at the end of vote processus !");
        //delete proposals && reset vote count for "white vote"
        for (uint i=0; i<proposalId; i++) {
           if(i==0){
               proposals[i].voteCount=0;
           }else{
               delete proposals[i];
           }
        }

        //delete voters
        for (uint i=0; i<addresses.length; i++) {
          delete whitelistedAddresses[addresses[i]];
        }

         //delete compute vote mapping
        for (uint i=0; i<voteCountGroupBy.length; i++) {
          delete nbProposalGroupByVoteCount[voteCountGroupBy[i]];
        }

        //delete proposals list
        delete proposalDescriptionList;

        //reset proposal counter to 1. 0 is used for "White vote"
        proposalId=1;

        //reset array used foe deletion
        delete addresses;
        delete voteCountGroupBy;

        //reset workflow
        currentWorkflow = WorkflowStatus.RegisteringVoters;
    }


    /******************* Workflow management********************/

    //contract will be deployed with default value for WorkflowStatus = 0 which means RegisteringVoters
    //so no need to define a step to move to RegisteringVoters phase

    /*function startRegisterVoterPhase() public onlyOwner{
        require(uint8(currentWorkflow) <=0,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = WorkflowStatus.RegisteringVoters;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
    }*/

    //only one fonction to manage vote phase
    //owner update phase by passing value requested
    function startNextPhase(WorkflowStatus _nextPhase) public onlyOwner {
        require(uint8(currentWorkflow) == uint8(_nextPhase)-1,"Phase invalid");
        WorkflowStatus oldStatus = currentWorkflow;
        currentWorkflow = _nextPhase;
        emit WorkflowStatusChange(oldStatus, currentWorkflow);
        //compute vote
        if(currentWorkflow == WorkflowStatus.VotesTallied){
            computeVote();
        }
    }
    

    //one function per phase

    /*function startProposalsRegistrationPhase() public onlyOwner{
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
    }*/
     /*************************************************************/
}