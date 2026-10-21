// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface ISolarisCrowdfund {
    function pledgeFunds(uint256 campaignId) external payable;
    function claimRefund(uint256 campaignId) external;
    function voteForMilestone(uint256 campaignId, uint256 milestoneId) external;
}
