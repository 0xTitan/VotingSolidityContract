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

    //list addess allowed to vote (whitelist)
    mapping(address => bool) whitelistedAddresses;
    //array representing proposal list
    Proposal[] public proposals;

    //Get the winning proposal id when votes are closed
    function winningProposalId() public view returns (uint){

    }

     //Get the proposal winner when votes are closed
    function getWinner () public view returns (Proposal memory){

    }
}
