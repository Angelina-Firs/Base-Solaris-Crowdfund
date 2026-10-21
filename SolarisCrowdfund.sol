// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract SolarisCrowdfund {
    enum CampaignState { Active, Succeeded, Canceled }

    struct Milestone {
        string description;
        uint256 allocationAmount;
        bool approved;
        bool paidOut;
    }

    struct Campaign {
        string title;
        address payable creator;
        uint256 goalAmount;
        uint256 totalRaised;
        uint256 deadline;
        CampaignState state;
        uint256 milestoneCount;
    }

    address payable public immutable platformManager;
    string public platformBrand;
    uint256 public campaignCounter;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(uint256 => Milestone)) public milestones;
    mapping(uint256 => mapping(address => uint256)) public pledges;

    event CampaignLaunched(uint256 indexed campaignId, string title, uint256 goal, uint256 deadline);
    event FundsPledged(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event MilestoneAdded(uint256 indexed campaignId, uint256 indexed milestoneId, uint256 allocation);
    event MilestoneApproved(uint256 indexed campaignId, uint256 indexed milestoneId);
    event MilestonePaid(uint256 indexed campaignId, uint256 indexed milestoneId, uint256 amount);
    event RefundClaimed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event BrandTagChanged(string newBrand);
    event CampaignTerminated(uint256 indexed campaignId, uint256 sweptFunds);

    modifier onlyManager() {
        require(msg.sender == platformManager, "Solaris: Unauthorized platform manager");
        _;
    }

    constructor() {
        platformManager = payable(msg.sender);
        platformBrand = "Solaris Base Launchpad v1";
    }

    // 1. Создание новой краудфандинговой кампании
    function createCampaign(
        string calldata title,
        uint256 goalAmount,
        uint256 durationSeconds
    ) external returns (uint256) {
        require(bytes(title).length > 0, "Solaris: Empty title");
        require(goalAmount > 0, "Solaris: Zero goal rejected");
        require(durationSeconds >= 60, "Solaris: Min duration 60s");

        campaignCounter++;
        campaigns[campaignCounter] = Campaign({
            title: title,
            creator: payable(msg.sender),
            goalAmount: goalAmount,
            totalRaised: 0,
            deadline: block.timestamp + durationSeconds,
            state: CampaignState.Active,
            milestoneCount: 0
        });

        emit CampaignLaunched(campaignCounter, title, goalAmount, block.timestamp + durationSeconds);
        return campaignCounter;
    }

    // 2. Внесение взноса в кампанию
    function pledgeFunds(uint256 campaignId) external payable {
        Campaign storage c = campaigns[campaignId];
        require(campaignId > 0 && campaignId <= campaignCounter, "Solaris: Invalid ID");
        require(c.state == CampaignState.Active, "Solaris: Campaign not active");
        require(block.timestamp < c.deadline, "Solaris: Campaign expired");
        require(msg.value > 0, "Solaris: Zero pledge");

        c.totalRaised += msg.value;
        pledges[campaignId][msg.sender] += msg.value;

        if (c.totalRaised >= c.goalAmount) {
            c.state = CampaignState.Succeeded;
        }

        emit FundsPledged(campaignId, msg.sender, msg.value);
    }

    // 3. Добавление промежуточного этапа (вехи) создателем кампании
    function addMilestone(
        uint256 campaignId,
        string calldata description,
        uint256 allocationAmount
    ) external {
        Campaign storage c = campaigns[campaignId];
        require(c.creator == msg.sender, "Solaris: Only creator can add milestones");
        require(allocationAmount > 0, "Solaris: Allocation must be positive");

        c.milestoneCount++;
        milestones[campaignId][c.milestoneCount] = Milestone({
            description: description,
            allocationAmount: allocationAmount,
            approved: false,
            paidOut: false
        });

        emit MilestoneAdded(campaignId, c.milestoneCount, allocationAmount);
    }

    // 4. Подтверждение выполнения вехи
    function approveMilestone(uint256 campaignId, uint256 milestoneId) external {
        Campaign storage c = campaigns[campaignId];
        require(c.creator == msg.sender, "Solaris: Only creator can approve");
        require(milestoneId > 0 && milestoneId <= c.milestoneCount, "Solaris: Invalid milestone ID");

        Milestone storage m = milestones[campaignId][milestoneId];
        require(!m.approved, "Solaris: Already approved");

        m.approved = true;
        emit MilestoneApproved(campaignId, milestoneId);
    }

    // 5. Выплата средств за выполненный этап
    function claimMilestonePayout(uint256 campaignId, uint256 milestoneId) external {
        Campaign storage c = campaigns[campaignId];
        require(c.creator == msg.sender, "Solaris: Only creator can claim payout");

        Milestone storage m = milestones[campaignId][milestoneId];
        require(m.approved, "Solaris: Milestone not approved yet");
        require(!m.paidOut, "Solaris: Milestone already paid");
        require(address(this).balance >= m.allocationAmount, "Solaris: Insufficient balance");

        m.paidOut = true;
        uint256 amount = m.allocationAmount;

        (bool sent, ) = c.creator.call{value: amount}("");
        require(sent, "Solaris: Payout transfer failed");

        emit MilestonePaid(campaignId, milestoneId, amount);
    }

    // 6. Возврат средств участнику при отмене или по запросу
    function claimRefund(uint256 campaignId) external {
        Campaign storage c = campaigns[campaignId];
        require(c.state == CampaignState.Canceled, "Solaris: Refunds only allowed on canceled campaigns");

        uint256 contributorPledge = pledges[campaignId][msg.sender];
        require(contributorPledge > 0, "Solaris: No pledge to refund");

        pledges[campaignId][msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: contributorPledge}("");
        require(sent, "Solaris: Refund failed");

        emit RefundClaimed(campaignId, msg.sender, contributorPledge);
    }

    // 7. Обновление бренда платформы
    function updatePlatformBrand(string calldata newBrand) external onlyManager {
        require(bytes(newBrand).length > 0, "Solaris: Empty brand tag");
        platformBrand = newBrand;
        emit BrandTagChanged(newBrand);
    }

    // 8. Аварийная отмена кампании менеджером и очистка остатка
    function emergencyCancelCampaign(uint256 campaignId) external onlyManager {
        Campaign storage c = campaigns[campaignId];
        require(campaignId > 0 && campaignId <= campaignCounter, "Solaris: Invalid campaign ID");
        require(c.state != CampaignState.Canceled, "Solaris: Already canceled");

        c.state = CampaignState.Canceled;
        uint256 remainingFunds = address(this).balance;

        if (remainingFunds > 0) {
            (bool sent, ) = platformManager.call{value: remainingFunds}("");
            require(sent, "Solaris: Emergency sweep failed");
        }

        emit CampaignTerminated(campaignId, remainingFunds);
    }

    // Чтение информации о кампании
    function getCampaignDetails(uint256 campaignId) external view returns (
        string memory title,
        address creator,
        uint256 goalAmount,
        uint256 totalRaised,
        uint256 deadline,
        CampaignState state,
        uint256 milestoneCount
    ) {
        Campaign memory c = campaigns[campaignId];
        return (c.title, c.creator, c.goalAmount, c.totalRaised, c.deadline, c.state, c.milestoneCount);
    }
}