// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/Checkpoints.sol";

contract GovernanceEngine {
    enum ProposalState { Pending, Active, Defeated, Succeeded, Queued, Executed, Expired }

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool queued;
        bool executed;
        uint256 eta;
    }

    ERC20Votes public govToken;
    uint256 public constant VOTING_DELAY = 1; // 1 block delay
    uint256 public votingPeriod; // Duration in blocks
    uint256 public proposalThreshold;
    uint256 public timelockDelay;

    Proposal[] public proposals;
    // proposalId => voter => voted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, address target, uint256 value, bytes data);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);

    constructor(
        address _govToken,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _timelockDelay
    ) {
        govToken = ERC20Votes(_govToken);
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        timelockDelay = _timelockDelay;
    }

    function propose(address _target, uint256 _value, bytes calldata _data) external returns (uint256) {
        require(govToken.getPastVotes(msg.sender, block.number - 1) >= proposalThreshold, "Below proposal threshold");

        uint256 proposalId = proposals.length;
        proposals.push(Proposal({
            target: _target,
            value: _value,
            data: _data,
            startBlock: block.number + VOTING_DELAY,
            endBlock: block.number + VOTING_DELAY + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            queued: false,
            executed: false,
            eta: 0
        }));

        emit ProposalCreated(proposalId, msg.sender, _target, _value, _data);
        return proposalId;
    }

    function castVote(uint256 _proposalId, bool _support) external {
        require(state(_proposalId) == ProposalState.Active, "Voting is not active");
        require(!hasVoted[_proposalId][msg.sender], "Already voted on this proposal");

        Proposal storage proposal = proposals[_proposalId];
        uint256 weight = govToken.getPastVotes(msg.sender, proposal.startBlock);
        require(weight > 0, "No voting power available");

        if (_support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        hasVoted[_proposalId][msg.sender] = true;
        emit VoteCast(msg.sender, _proposalId, _support, weight);
    }

    function queue(uint256 _proposalId) external {
        require(state(_proposalId) == ProposalState.Succeeded, "Proposal has not succeeded");
        Proposal storage proposal = proposals[_proposalId];
        
        proposal.queued = true;
        proposal.eta = block.timestamp + timelockDelay;

        emit ProposalQueued(_proposalId, proposal.eta);
    }

    function execute(uint256 _proposalId) external payable {
        require(state(_proposalId) == ProposalState.Queued, "Proposal is not queued");
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.eta, "Timelock delay incomplete");

        proposal.executed = true;

        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Governance execution transaction failed");

        emit ProposalExecuted(_proposalId);
    }

    function state(uint256 _proposalId) public view returns (ProposalState) {
        require(_proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];

        if (proposal.executed) return ProposalState.Executed;
        if (block.number < proposal.startBlock) return ProposalState.Pending;
        if (block.number <= proposal.endBlock) return ProposalState.Active;
        
        if (proposal.forVotes <= proposal.againstVotes) return ProposalState.Defeated;
        
        if (!proposal.queued) return ProposalState.Succeeded;
        if (proposal.eta > 0 && block.timestamp < proposal.eta) return ProposalState.Queued;
        if (proposal.eta > 0 && block.timestamp >= proposal.eta + 3 days) return ProposalState.Expired;
        
        return ProposalState.Queued;
    }
}
