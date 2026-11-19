// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentWorks — Agent ID-gated task escrow for AI agents
/// @notice Every state-changing action requires the caller to hold a SPACE ID
/// Agent ID (non-transferable ERC-721, `balanceOf > 0`). Reputation is tied
/// to the Agent ID wallet and cannot be transferred or reset.
/// @dev Gas-lean by design: custom errors, packed structs, no heavy
/// inheritance. Only interface needed from Agent ID is `balanceOf`.
/// Mainnet Agent ID registry: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
/// Testnet: deploy MockAgentID.sol and pass its address instead.

interface IAgentID {
    function balanceOf(address account) external view returns (uint256);
}

contract AgentWorksEscrow {
    // ---- errors (cheaper than revert strings) ----
    error NotAgentIdHolder();
    error NotOwner();
    error NotArbitrator();
    error Paused();
    error Reentrancy();
    error InvalidReward();
    error InvalidDeadline();
    error InvalidTitle();
    error InvalidRating();
    error InvalidFee();
    error SelfAccept();
    error TaskNotFound();
    error WrongStatus();
    error NotPoster();
    error NotWorker();
    error NotParty();
    error TransferFailed();

    enum Status {
        Open, // 0: posted, awaiting worker
        Assigned, // 1: worker accepted
        Submitted, // 2: work submitted, awaiting poster
        Completed, // 3: paid out
        Disputed, // 4: under arbitration
        Cancelled, // 5: refunded to poster
        Refunded // 6: dispute resolved in poster's favour
    }

    struct Task {
        address poster; // 20 bytes
        address worker; // 20 bytes
        uint128 reward; // reward in wei (<= ~3.4e26 wei, ample for BNB)
        uint64 deadline; // unix seconds
        uint64 createdAt;
        Status status; // 1 byte
        uint8 rating; // 1-5 once completed, else 0
        bytes32 descriptionHash; // hash of off-chain spec (e.g. IPFS CID hash)
        bytes32 proofHash; // hash of deliverable, set on submit
        string title; // short title, <= 80 chars (dynamic slot, last)
    }

    struct Reputation {
        uint32 completed;
        uint32 disputed;
        uint32 ratingSum;
        uint32 ratingCount;
    }

    IAgentID public immutable agentId;
    address public owner;
    address public arbitrator;
    uint256 public feeBps; // 200 = 2%
    uint256 public constant MAX_FEE_BPS = 500; // 5%
    bool public paused;

    uint256 public taskCount;
    mapping(uint256 => Task) private tasks;
    mapping(address => Reputation) private reputations;
    mapping(address => uint256[]) private tasksByPoster;
    mapping(address => uint256[]) private tasksByWorker;

    // simple reentrancy guard (uint, not transient: BSC-compatible)
    uint256 private locked;

    event TaskCreated(uint256 indexed taskId, address indexed poster, uint128 reward, uint64 deadline, string title);
    event TaskAccepted(uint256 indexed taskId, address indexed worker);
    event WorkSubmitted(uint256 indexed taskId, address indexed worker, bytes32 proofHash);
    event TaskCompleted(uint256 indexed taskId, address indexed worker, uint256 paid, uint256 fee, uint8 rating);
    event TaskDisputed(uint256 indexed taskId, address indexed by);
    event DisputeResolved(uint256 indexed taskId, bool paidWorker);
    event TaskCancelled(uint256 indexed taskId, address indexed poster);
    event Rated(uint256 indexed taskId, address indexed worker, uint8 rating);
    event FeeUpdated(uint256 feeBps);
    event ArbitratorUpdated(address arbitrator);
    event PausedSet(bool paused);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    modifier onlyAgent() {
        if (agentId.balanceOf(msg.sender) == 0) revert NotAgentIdHolder();
        _;
    }
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }
    modifier nonReentrant() {
        if (locked == 1) revert Reentrancy();
        locked = 1;
        _;
        locked = 0;
    }

    constructor(address _agentId, address _arbitrator, address _owner) {
        agentId = IAgentID(_agentId);
        // Owner is an explicit argument (not msg.sender) so the contract can
        // also be deployed through a CREATE2 factory, where msg.sender would
        // be the factory. The owner is the user's wallet on mainnet.
        owner = _owner == address(0) ? msg.sender : _owner;
        arbitrator = _arbitrator == address(0) ? owner : _arbitrator;
        feeBps = 200; // 2%
    }

    // ---- owner / admin (permissions disclosed in README/DESIGN) ----
    /// @notice Owner cannot withdraw escrowed task funds, change tasks, or
    /// force a payout to a third address. Only: pause, fee (<=5%), arbitrator.
    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert InvalidFee();
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setArbitrator(address _arbitrator) external onlyOwner {
        arbitrator = _arbitrator;
        emit ArbitratorUpdated(_arbitrator);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedSet(_paused);
    }

    function transferOwnership(address _owner) external onlyOwner {
        owner = _owner;
    }

    // ---- views ----
    function hasAgentId(address account) public view returns (bool) {
        return agentId.balanceOf(account) > 0;
    }

    function getTask(uint256 taskId) external view returns (Task memory) {
        if (taskId >= taskCount) revert TaskNotFound();
        return tasks[taskId];
    }

    function getReputation(address account)
        external
        view
        returns (uint32 completed, uint32 disputed, uint32 ratingSum, uint32 ratingCount, uint256 averageRatingX100)
    {
        Reputation memory r = reputations[account];
        uint256 avg = r.ratingCount == 0 ? 0 : (uint256(r.ratingSum) * 100) / r.ratingCount;
        return (r.completed, r.disputed, r.ratingSum, r.ratingCount, avg);
    }

    function tasksOfPoster(address poster) external view returns (uint256[] memory) {
        return tasksByPoster[poster];
    }

    function tasksOfWorker(address worker) external view returns (uint256[] memory) {
        return tasksByWorker[worker];
    }

    // ---- core flow ----
    function createTask(string calldata title, bytes32 descriptionHash, uint64 deadline)
        external
        payable
        onlyAgent
        whenNotPaused
        returns (uint256 taskId)
    {
        if (msg.value == 0) revert InvalidReward();
        if (msg.value > type(uint128).max) revert InvalidReward();
        if (deadline <= block.timestamp) revert InvalidDeadline();
        if (bytes(title).length == 0 || bytes(title).length > 80) revert InvalidTitle();

        taskId = taskCount++;
        Task storage t = tasks[taskId];
        t.poster = msg.sender;
        t.reward = uint128(msg.value);
        t.deadline = deadline;
        t.createdAt = uint64(block.timestamp);
        t.status = Status.Open;
        t.descriptionHash = descriptionHash;
        t.title = title;
        tasksByPoster[msg.sender].push(taskId);

        emit TaskCreated(taskId, msg.sender, uint128(msg.value), deadline, title);
    }

    function acceptTask(uint256 taskId) external onlyAgent whenNotPaused {
        if (taskId >= taskCount) revert TaskNotFound();
        Task storage t = tasks[taskId];
        if (t.status != Status.Open) revert WrongStatus();
        if (msg.sender == t.poster) revert SelfAccept();
        t.worker = msg.sender;
        t.status = Status.Assigned;
        tasksByWorker[msg.sender].push(taskId);
        emit TaskAccepted(taskId, msg.sender);
    }

    function submitWork(uint256 taskId, bytes32 proofHash) external whenNotPaused {
        if (taskId >= taskCount) revert TaskNotFound();
        Task storage t = tasks[taskId];
        if (t.status != Status.Assigned) revert WrongStatus();
        if (msg.sender != t.worker) revert NotWorker();
        if (block.timestamp > t.deadline) revert InvalidDeadline();
        t.proofHash = proofHash;
        t.status = Status.Submitted;
        emit WorkSubmitted(taskId, msg.sender, proofHash);
    }

    function confirmCompletion(uint256 taskId, uint8 rating)
        external
        onlyAgent
        whenNotPaused
        nonReentrant
    {
        if (taskId >= taskCount) revert TaskNotFound();
        if (rating < 1 || rating > 5) revert InvalidRating();
        Task storage t = tasks[taskId];
        if (t.status != Status.Submitted) revert WrongStatus();
        if (msg.sender != t.poster) revert NotPoster();

        uint256 fee = (uint256(t.reward) * feeBps) / 10_000;
        uint256 paid = uint256(t.reward) - fee;
        address worker = t.worker;
        t.status = Status.Completed;
        t.rating = rating;

        Reputation storage r = reputations[worker];
        r.completed += 1;
        r.ratingSum += rating;
        r.ratingCount += 1;

        emit TaskCompleted(taskId, worker, paid, fee, rating);
        emit Rated(taskId, worker, rating);

        (bool okW,) = worker.call{value: paid}("");
        if (!okW) revert TransferFailed();
        if (fee > 0) {
            (bool okF,) = owner.call{value: fee}("");
            if (!okF) revert TransferFailed();
        }
    }

    function raiseDispute(uint256 taskId) external whenNotPaused {
        if (taskId >= taskCount) revert TaskNotFound();
        Task storage t = tasks[taskId];
        if (t.status != Status.Assigned && t.status != Status.Submitted) revert WrongStatus();
        if (msg.sender != t.poster && msg.sender != t.worker) revert NotParty();
        t.status = Status.Disputed;
        reputations[t.worker].disputed += 1;
        emit TaskDisputed(taskId, msg.sender);
    }

    /// @notice Arbitrator pays the worker (fee applies) OR refunds the poster.
    /// Never pays a third address.
    function resolveDispute(uint256 taskId, bool payWorker) external nonReentrant {
        if (msg.sender != arbitrator) revert NotArbitrator();
        if (taskId >= taskCount) revert TaskNotFound();
        Task storage t = tasks[taskId];
        if (t.status != Status.Disputed) revert WrongStatus();

        if (payWorker) {
            uint256 fee = (uint256(t.reward) * feeBps) / 10_000;
            uint256 paid = uint256(t.reward) - fee;
            address worker = t.worker;
            t.status = Status.Completed;
            reputations[worker].completed += 1;
            emit DisputeResolved(taskId, true);
            (bool okW,) = worker.call{value: paid}("");
            if (!okW) revert TransferFailed();
            if (fee > 0) {
                (bool okF,) = owner.call{value: fee}("");
                if (!okF) revert TransferFailed();
            }
        } else {
            address poster = t.poster;
            uint256 reward = t.reward;
            t.status = Status.Refunded;
            emit DisputeResolved(taskId, false);
            (bool okP,) = poster.call{value: reward}("");
            if (!okP) revert TransferFailed();
        }
    }

    function cancelTask(uint256 taskId) external nonReentrant {
        if (taskId >= taskCount) revert TaskNotFound();
        Task storage t = tasks[taskId];
        if (msg.sender != t.poster) revert NotPoster();
        if (t.status == Status.Open) {
            // full refund
        } else if (t.status == Status.Assigned && block.timestamp > t.deadline) {
            // expired, never submitted: full refund
        } else {
            revert WrongStatus();
        }
        uint256 reward = t.reward;
        address poster = t.poster;
        t.status = Status.Cancelled;
        emit TaskCancelled(taskId, poster);
        (bool ok,) = poster.call{value: reward}("");
        if (!ok) revert TransferFailed();
    }
}
