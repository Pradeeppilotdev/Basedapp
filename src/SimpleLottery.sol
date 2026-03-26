// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title SimpleLottery
 * @notice A daily lottery contract with commit-reveal randomness
 * @dev Users buy tickets for a 24-hour lottery round. Winner selected via commit-reveal pattern.
 *
 * Features:
 * - Fixed 0.01 ETH entry fee per ticket
 * - 24-hour draw cycles
 * - Users can buy 1-10 tickets per transaction
 * - Commit-reveal randomness (cheap, secure enough for MVP)
 * - 90% to winner, 10% platform fee
 * - Emergency pause mechanism
 *
 * Security:
 * - ReentrancyGuard on all external calls
 * - Pull-over-push prize distribution
 * - Access control on admin functions
 * - Two-step commit-reveal prevents manipulation
 */
contract SimpleLottery is Ownable, ReentrancyGuard, Pausable {

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public constant MAX_TICKETS_PER_TX = 10;
    uint256 public constant ROUND_DURATION = 24 hours;
    uint256 public constant PLATFORM_FEE_PERCENT = 10; // 10%
    uint256 public constant COMMIT_REVEAL_BLOCKS = 2; // Min blocks between commit and reveal

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    // Current round state
    uint256 public currentRoundId;
    uint256 public roundStartTime;
    uint256 public roundEndTime;

    // Round data
    struct Round {
        uint256 roundId;
        uint256 startTime;
        uint256 endTime;
        uint256 totalTickets;
        uint256 prizePool;
        address winner;
        bool drawn;
        bool prizeClaimed;
        bytes32 commitHash;
        uint256 commitBlock;
    }

    mapping(uint256 => Round) public rounds;

    // User tickets per round: roundId => user => ticket count
    mapping(uint256 => mapping(address => uint256)) public userTickets;

    // Ticket ownership: roundId => ticketIndex => user address
    mapping(uint256 => mapping(uint256 => address)) public ticketOwners;

    // Platform fees collected
    uint256 public collectedFees;

    // Fee collector address
    address public feeCollector;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RoundStarted(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event TicketsPurchased(uint256 indexed roundId, address indexed buyer, uint256 numTickets, uint256 totalPaid);
    event DrawCommitted(uint256 indexed roundId, bytes32 commitHash, uint256 blockNumber);
    event WinnerSelected(uint256 indexed roundId, address indexed winner, uint256 prize);
    event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint256 amount);
    event FeesCollected(address indexed collector, uint256 amount);
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error RoundNotActive();
    error RoundNotEnded();
    error RoundAlreadyDrawn();
    error InvalidTicketCount();
    error InvalidPayment();
    error NoTicketsInRound();
    error NotWinner();
    error PrizeAlreadyClaimed();
    error DrawNotCommitted();
    error TooEarlyToReveal();
    error InvalidReveal();
    error NoFeesToCollect();
    error InvalidFeeCollector();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _feeCollector) Ownable(msg.sender) {
        if (_feeCollector == address(0)) revert InvalidFeeCollector();
        feeCollector = _feeCollector;

        // Start first round immediately
        _startNewRound();
    }

    /*//////////////////////////////////////////////////////////////
                            USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Buy lottery tickets for the current round
     * @param _numTickets Number of tickets to purchase (1-10)
     */
    function enterLottery(uint256 _numTickets) external payable nonReentrant whenNotPaused {
        // Validate round is active
        if (block.timestamp >= roundEndTime) revert RoundNotActive();

        // Validate ticket count
        if (_numTickets == 0 || _numTickets > MAX_TICKETS_PER_TX) {
            revert InvalidTicketCount();
        }

        // Validate payment
        uint256 requiredPayment = TICKET_PRICE * _numTickets;
        if (msg.value != requiredPayment) revert InvalidPayment();

        Round storage round = rounds[currentRoundId];

        // Assign tickets to user
        uint256 startTicketIndex = round.totalTickets;
        for (uint256 i = 0; i < _numTickets; i++) {
            ticketOwners[currentRoundId][startTicketIndex + i] = msg.sender;
        }

        // Update state
        userTickets[currentRoundId][msg.sender] += _numTickets;
        round.totalTickets += _numTickets;
        round.prizePool += msg.value;

        emit TicketsPurchased(currentRoundId, msg.sender, _numTickets, msg.value);
    }

    /**
     * @notice Claim prize if you're the winner
     * @param _roundId Round ID to claim prize from
     */
    function claimPrize(uint256 _roundId) external nonReentrant {
        Round storage round = rounds[_roundId];

        // Validate draw is complete
        if (!round.drawn) revert RoundNotEnded();

        // Validate caller is winner
        if (round.winner != msg.sender) revert NotWinner();

        // Validate prize not already claimed
        if (round.prizeClaimed) revert PrizeAlreadyClaimed();

        // Calculate winner's prize (90% of pool)
        uint256 platformFee = (round.prizePool * PLATFORM_FEE_PERCENT) / 100;
        uint256 winnerPrize = round.prizePool - platformFee;

        // Mark as claimed BEFORE external call (CEI pattern)
        round.prizeClaimed = true;
        collectedFees += platformFee;

        // Transfer prize to winner
        (bool success, ) = msg.sender.call{value: winnerPrize}("");
        require(success, "Prize transfer failed");

        emit PrizeClaimed(_roundId, msg.sender, winnerPrize);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Commit to a draw (step 1 of commit-reveal)
     * @param _commitHash Hash of (roundId + nonce) - keep nonce secret!
     * @dev Admin should generate random nonce off-chain and hash it with roundId
     */
    function commitDraw(bytes32 _commitHash) external onlyOwner {
        // Validate round has ended
        if (block.timestamp < roundEndTime) revert RoundNotEnded();

        Round storage round = rounds[currentRoundId];

        // Validate not already drawn
        if (round.drawn) revert RoundAlreadyDrawn();

        // Validate round has tickets
        if (round.totalTickets == 0) revert NoTicketsInRound();

        // Store commitment
        round.commitHash = _commitHash;
        round.commitBlock = block.number;

        emit DrawCommitted(currentRoundId, _commitHash, block.number);
    }

    /**
     * @notice Reveal the nonce and select winner (step 2 of commit-reveal)
     * @param _nonce The secret nonce used in commitment
     * @dev Must wait at least COMMIT_REVEAL_BLOCKS after commit
     */
    function revealDraw(uint256 _nonce) external onlyOwner {
        Round storage round = rounds[currentRoundId];

        // Validate draw was committed
        if (round.commitHash == bytes32(0)) revert DrawNotCommitted();

        // Validate enough blocks have passed since commit
        if (block.number < round.commitBlock + COMMIT_REVEAL_BLOCKS) {
            revert TooEarlyToReveal();
        }

        // Verify the reveal matches the commitment
        bytes32 revealHash = keccak256(abi.encodePacked(currentRoundId, _nonce));
        if (revealHash != round.commitHash) revert InvalidReveal();

        // Generate randomness using multiple entropy sources
        uint256 randomSeed = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(round.commitBlock), // Block hash from commit
                    _nonce,                       // Off-chain randomness
                    currentRoundId,               // Round identifier
                    round.totalTickets,           // Total participants
                    block.prevrandao              // Consensus randomness (post-merge)
                )
            )
        );

        // Select winning ticket
        uint256 winningTicketIndex = randomSeed % round.totalTickets;
        address winner = ticketOwners[currentRoundId][winningTicketIndex];

        // Update round state
        round.winner = winner;
        round.drawn = true;

        emit WinnerSelected(currentRoundId, winner, round.prizePool);

        // Start next round
        _startNewRound();
    }

    /**
     * @notice Collect accumulated platform fees
     */
    function collectFees() external onlyOwner nonReentrant {
        if (collectedFees == 0) revert NoFeesToCollect();

        uint256 amount = collectedFees;
        collectedFees = 0;

        (bool success, ) = feeCollector.call{value: amount}("");
        require(success, "Fee transfer failed");

        emit FeesCollected(feeCollector, amount);
    }

    /**
     * @notice Update fee collector address
     * @param _newCollector New fee collector address
     */
    function setFeeCollector(address _newCollector) external onlyOwner {
        if (_newCollector == address(0)) revert InvalidFeeCollector();

        address oldCollector = feeCollector;
        feeCollector = _newCollector;

        emit FeeCollectorUpdated(oldCollector, _newCollector);
    }

    /**
     * @notice Pause the contract (emergency only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Start a new lottery round
     */
    function _startNewRound() internal {
        currentRoundId++;
        roundStartTime = block.timestamp;
        roundEndTime = roundStartTime + ROUND_DURATION;

        rounds[currentRoundId] = Round({
            roundId: currentRoundId,
            startTime: roundStartTime,
            endTime: roundEndTime,
            totalTickets: 0,
            prizePool: 0,
            winner: address(0),
            drawn: false,
            prizeClaimed: false,
            commitHash: bytes32(0),
            commitBlock: 0
        });

        emit RoundStarted(currentRoundId, roundStartTime, roundEndTime);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get current round information
     */
    function getCurrentRound() external view returns (
        uint256 roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 totalTickets,
        uint256 prizePool,
        bool isActive
    ) {
        Round storage round = rounds[currentRoundId];
        return (
            round.roundId,
            round.startTime,
            round.endTime,
            round.totalTickets,
            round.prizePool,
            block.timestamp < roundEndTime
        );
    }

    /**
     * @notice Get user's tickets for a specific round
     * @param _roundId Round ID
     * @param _user User address
     */
    function getUserTickets(uint256 _roundId, address _user) external view returns (uint256) {
        return userTickets[_roundId][_user];
    }

    /**
     * @notice Get round details by ID
     * @param _roundId Round ID
     */
    function getRound(uint256 _roundId) external view returns (Round memory) {
        return rounds[_roundId];
    }

    /**
     * @notice Check if current round is active
     */
    function isRoundActive() external view returns (bool) {
        return block.timestamp < roundEndTime && rounds[currentRoundId].totalTickets < type(uint256).max;
    }

    /**
     * @notice Get time remaining in current round
     */
    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= roundEndTime) return 0;
        return roundEndTime - block.timestamp;
    }
}
