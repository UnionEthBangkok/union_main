// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "../base/BaseUnion.sol";
import "../common/Singleton.sol";
import "../common/StorageAccessible.sol";
import {TestFtsoV2Interface} from "@flarenetwork/flare-periphery-contracts/coston2/TestFtsoV2Interface.sol";
import {ContractRegistry} from "@flarenetwork/flare-periphery-contracts/coston2/ContractRegistry.sol";
import {IFtsoFeedIdConverter} from "@flarenetwork/flare-periphery-contracts/coston2/IFtsoFeedIdConverter.sol";
import {IFastUpdatesConfiguration} from "@flarenetwork/flare-periphery-contracts/coston2/IFastUpdatesConfiguration.sol";

/**
 * @title Traditional Union
 * @author Anoy Roy Chowdhury - <anoyroyc3545@gmail.com>
 * @notice Traditional Union contract
 */
contract FlareUnion is Singleton, StorageAccessible, BaseUnion {
    TestFtsoV2Interface internal ftsoV2;
    IFtsoFeedIdConverter internal feedIdConverter;
    bytes21 public flrUsdId = 0x01464c522f55534400000000000000000000000000;

    constructor() {
        ftsoV2 = ContractRegistry.getTestFtsoV2();
        feedIdConverter = ContractRegistry.getFtsoFeedIdConverter();
    }

    /**
     * @notice Get the Flare-USD price
     * @return
     * @return
     * @return
     */
    function getFlrUsdPrice() public view returns (uint256, int8, uint64) {
        (uint256 feedValue, int8 decimals, uint64 timestamp) = ftsoV2
            .getFeedById(flrUsdId);

        return (feedValue, decimals, timestamp);
    }

    /**
     * @notice Initializes the Traditional Union contract
     * @param _daoToken The address of the DAO token
     * @param _dao The address of the DAO contract
     * @param _name The name of the union
     * @param admin The address of the admin
     */
    function initializeTraditionalUnion(
        address _daoToken,
        address _dao,
        string memory _name,
        address admin
    ) external {
        initializeUnion(_daoToken, _dao, _name, admin);
    }

    /**
     * @notice Get the voting power of a member
     * @param member The address of the member
     */
    function getVotingPower(
        address member
    ) public view override returns (uint256) {
        (uint256 feedValue, , ) = getFlrUsdPrice();

        uint256 flrBalance = tokenDelegate[member];

        return flrBalance * feedValue;
    }

    /**
     * @notice Join the union
     * @param _tokenToDelegate The amount of tokens to delegate
     */
    function joinUnion(uint256 _tokenToDelegate) public override {
        super.joinUnion(_tokenToDelegate);
    }

    /**
     * @notice Leave the union
     */
    function leaveUnion() public override {
        super.leaveUnion();
    }

    /**
     * @notice Vote on a proposal
     * @param proposalId The id of the proposal
     * @param decision The decision of the voter
     */
    function voteInternal(uint256 proposalId, uint8 decision) public {
        InternalVotes storage internalVote = internalVotes[proposalId];

        (
            address proposer,
            ,
            ,
            uint256 startBlock,
            uint256 endBlock,
            ,
            ,
            ,

        ) = dao.getProposal(proposalId);

        require(proposer != address(0), "Invalid proposal");
        require(!internalVote.executed, "Already executed");
        require(block.number <= endBlock, "Voting period ended");
        require(!internalVote.hasVoted[msg.sender], "Already voted");
        require(block.number >= startBlock, "Voting not started");
        require(
            block.number < endBlock - internalDeadlineInterval,
            "Internal voting deadline passed"
        );
        require(tokenDelegate[msg.sender] >= 0, "No Tokens delegated");

        uint256 weight = getVotingPower(msg.sender);

        require(weight > 0, "No voting power");

        if (decision == 1) {
            internalVote.forVotes += weight;
        } else if (decision == 2) {
            internalVote.againstVotes += weight;
        } else {
            internalVote.abstainVotes += weight;
        }

        internalVote.hasVoted[msg.sender] = true;

        emit InternalVoteCast(proposalId, decision, weight);
    }
}