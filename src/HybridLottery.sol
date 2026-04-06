// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title HybridLottery
 * @notice A hybrid lottery with ETH prizes + token rewards
 * @dev Users buy tickets with ETH and receive instant token rewards + chance to win ETH + bonus tokens
 *
 * Features:
 * - Ultra-low 0.0001 ETH entry fee per ticket
 * - 24-hour draw cycles
 * - Users can buy 1-10 tickets per transaction
 * - Instant token reward: 100 BASED per ticket
 * - Winner gets 80% ETH prize + 10,000 bonus BASED tokens
 * - 20% to treasury (funds liquidity pool creation)
 * - Commit-reveal randomness (cheap, secure enough for MVP)
 * - Self-sustaining: Treasury funds liquidity when threshold reached
 *
 * Economics:
 * - Entry: 0.0001 ETH → Get 100 BASED + lottery entry
 * - Winner: 80% of pool + 10,000 BASED bonus
 * - Treasury: 20% (accumulates for liquidity)
 * - Liquidity: Created when treasury >= 0.1 ETH
 */
contract HybridLottery is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TICKET_PRICE = 0.0001 ether;
    uint256 public constant MAX_TICKETS_PER_TX = 10;
    uint256 public constant ROUND_DURATION = 24 hours;
    uint256 public constant WINNER_PERCENTAGE = 80; // 80% to winner
    uint256 public constant TREASURY_PERCENTAGE = 20; // 20% to treasury
    uint256 public constant COMMIT_REVEAL_BLOCKS = 2;
    
    // Token rewards
    uint256 public constant TOKENS_PER_TICKET = 100 * 10**18; // 100 BASED per ticket
    uint256 public constant WINNER_BONUS_TOKENS = 10_000 * 10**18; // 10k BASED winner bonus
    
    // Liquidity thresholds
    uint256 public constant LIQUIDITY_THRESHOLD = 0.1 ether; // Min treasury to create liquidity
    uint256 public constant LIQUIDITY_ETH_AMOUNT = 0.05 ether; // ETH for liquidity pool
    uint256 public constant LIQUIDITY_TOKEN_AMOUNT = 50_000_000 * 10**18; // 50M tokens for pool

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    // Token contract
    IERC20 public immutable basedToken;

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

    // Treasury for liquidity creation
    uint256 public treasuryBalance;
    
    // Liquidity status
    bool public liquidityCreated;
    address public liquidityPool; // Address of created Uniswap pool
    
    // Stats
    uint256 public totalTokensDistributed;
    uint256 public totalParticipants;

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event RoundStarted(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event TicketsPurchased(
        uint256 indexed roundId, 
        address indexed buyer, 
        uint256 numTickets, 
        uint256 ethPaid,
        uint256 tokensReceived
    );
    event DrawCommitted(uint256 indexed roundId, bytes32 commitHash, uint256 blockNumber);
    event WinnerSelected(
        uint256 indexed roundId, 
        address indexed winner, 
        uint256 ethPrize,
        uint256 tokenBonus
    );
    event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint256 ethAmount, uint256 tokenAmount);
    event TreasuryUpdated(uint256 newBalance);
    event LiquidityCreated(address indexed pool, uint256 ethAmount, uint256 tokenAmount);

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
    error DrawAlreadyCommitted();
    error TooEarlyToReveal();
    error InvalidReveal();
    error InsufficientTreasury();
    error LiquidityAlreadyCreated();
    error InsufficientTokenBalance();
    error InvalidTokenAddress();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _basedToken) Ownable(msg.sender) {
        if (_basedToken == address(0)) revert InvalidTokenAddress();
        basedToken = IERC20(_basedToken);

        // Start first round immediately
        _startNewRound();
    }

    /*//////////////////////////////////////////////////////////////
                             USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Buy lottery tickets and receive instant token rewards
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

        // Calculate splits
        uint256 treasuryAmount = (msg.value * TREASURY_PERCENTAGE) / 100;
        uint256 prizeAmount = msg.value - treasuryAmount;

        // Update state
        userTickets[currentRoundId][msg.sender] += _numTickets;
        round.totalTickets += _numTickets;
        round.prizePool += prizeAmount;
        treasuryBalance += treasuryAmount;

        // Distribute instant token rewards
        uint256 tokenReward = TOKENS_PER_TICKET * _numTickets;
        totalTokensDistributed += tokenReward;
        
        if (userTickets[currentRoundId][msg.sender] == _numTickets) {
            totalParticipants++;
        }

        basedToken.safeTransfer(msg.sender, tokenReward);

        emit TicketsPurchased(currentRoundId, msg.sender, _numTickets, msg.value, tokenReward);
        emit TreasuryUpdated(treasuryBalance);
    }

    /**
     * @notice Claim prize if you're the winner (ETH + bonus tokens)
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

        uint256 ethPrize = round.prizePool;
        uint256 tokenBonus = WINNER_BONUS_TOKENS;

        // Mark as claimed BEFORE external calls (CEI pattern)
        round.prizeClaimed = true;
        totalTokensDistributed += tokenBonus;

        // Transfer ETH prize
        (bool success, ) = msg.sender.call{value: ethPrize}("");
        require(success, "ETH transfer failed");

        // Transfer bonus tokens
        basedToken.safeTransfer(msg.sender, tokenBonus);

        emit PrizeClaimed(_roundId, msg.sender, ethPrize, tokenBonus);
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Commit to a draw (step 1 of commit-reveal)
     * @param _commitHash Hash of (roundId + nonce) - keep nonce secret!
     */
    function commitDraw(bytes32 _commitHash) external onlyOwner {
        // Validate round has ended
        if (block.timestamp < roundEndTime) revert RoundNotEnded();

        Round storage round = rounds[currentRoundId];

        // Validate not already drawn
        if (round.drawn) revert RoundAlreadyDrawn();

        // Validate round has tickets
        if (round.totalTickets == 0) revert NoTicketsInRound();

        // Prevent commitment overwrite
        if (round.commitHash != bytes32(0)) revert DrawAlreadyCommitted();

        // Store commitment
        round.commitHash = _commitHash;
        round.commitBlock = block.number;

        emit DrawCommitted(currentRoundId, _commitHash, block.number);
    }

    /**
     * @notice Reveal the nonce and select winner (step 2 of commit-reveal)
     * @param _nonce The secret nonce used in commitment
     */
    function revealDraw(uint256 _nonce) external onlyOwner {
        Round storage round = rounds[currentRoundId];

        // Validate draw was committed
        if (round.commitHash == bytes32(0)) revert DrawNotCommitted();

        // Validate enough blocks have passed
        if (block.number < round.commitBlock + COMMIT_REVEAL_BLOCKS) {
            revert TooEarlyToReveal();
        }

        // Verify the reveal matches the commitment
        bytes32 revealHash = keccak256(abi.encodePacked(currentRoundId, _nonce));
        if (revealHash != round.commitHash) revert InvalidReveal();

        // Generate randomness
        uint256 randomSeed = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(round.commitBlock),
                    _nonce,
                    currentRoundId,
                    round.totalTickets,
                    block.prevrandao
                )
            )
        );

        // Select winning ticket
        uint256 winningTicketIndex = randomSeed % round.totalTickets;
        address winner = ticketOwners[currentRoundId][winningTicketIndex];

        // Update round state
        round.winner = winner;
        round.drawn = true;

        emit WinnerSelected(currentRoundId, winner, round.prizePool, WINNER_BONUS_TOKENS);

        // Start next round
        _startNewRound();
    }

    /**
     * @notice Create liquidity pool on Uniswap when treasury threshold is reached
     * @dev This function will be called manually by admin when ready
     * @dev In production, integrate with Uniswap V3 factory to create pool
     * @param _poolAddress Address of the created Uniswap pool (for record keeping)
     */
    function createLiquidity(address _poolAddress) external onlyOwner nonReentrant {
        // Validate treasury has enough funds
        if (treasuryBalance < LIQUIDITY_THRESHOLD) revert InsufficientTreasury();
        
        // Validate liquidity not already created
        if (liquidityCreated) revert LiquidityAlreadyCreated();
        
        // Validate sufficient token balance
        if (basedToken.balanceOf(address(this)) < LIQUIDITY_TOKEN_AMOUNT) {
            revert InsufficientTokenBalance();
        }

        // Mark liquidity as created
        liquidityCreated = true;
        liquidityPool = _poolAddress;

        // Deduct from treasury
        treasuryBalance -= LIQUIDITY_ETH_AMOUNT;

        // In production: Transfer tokens and ETH to Uniswap pool
        // For MVP: Admin will manually create pool and call this function for record-keeping
        // The actual pool creation happens off-chain via Uniswap interface
        
        emit LiquidityCreated(_poolAddress, LIQUIDITY_ETH_AMOUNT, LIQUIDITY_TOKEN_AMOUNT);
        emit TreasuryUpdated(treasuryBalance);
    }

    /**
     * @notice Withdraw tokens for liquidity pool creation (called by admin before creating pool)
     * @param _amount Amount of tokens to withdraw
     */
    function withdrawTokensForLiquidity(uint256 _amount) external onlyOwner nonReentrant {
        if (!liquidityCreated && treasuryBalance < LIQUIDITY_THRESHOLD) {
            revert InsufficientTreasury();
        }
        
        basedToken.safeTransfer(msg.sender, _amount);
    }

    /**
     * @notice Withdraw ETH for liquidity pool creation (called by admin before creating pool)
     * @param _amount Amount of ETH to withdraw
     */
    function withdrawETHForLiquidity(uint256 _amount) external onlyOwner nonReentrant {
        if (!liquidityCreated && treasuryBalance < LIQUIDITY_THRESHOLD) {
            revert InsufficientTreasury();
        }
        
        require(_amount <= treasuryBalance, "Insufficient treasury balance");
        
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "ETH transfer failed");
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
     */
    function getUserTickets(uint256 _roundId, address _user) external view returns (uint256) {
        return userTickets[_roundId][_user];
    }

    /**
     * @notice Get round details by ID
     */
    function getRound(uint256 _roundId) external view returns (Round memory) {
        return rounds[_roundId];
    }

    /**
     * @notice Check if current round is active
     */
    function isRoundActive() external view returns (bool) {
        return block.timestamp < roundEndTime;
    }

    /**
     * @notice Get time remaining in current round
     */
    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= roundEndTime) return 0;
        return roundEndTime - block.timestamp;
    }

    /**
     * @notice Check if treasury has reached liquidity threshold
     */
    function canCreateLiquidity() external view returns (bool) {
        return treasuryBalance >= LIQUIDITY_THRESHOLD && !liquidityCreated;
    }

    /**
     * @notice Get contract stats
     */
    function getStats() external view returns (
        uint256 _totalTokensDistributed,
        uint256 _totalParticipants,
        uint256 _treasuryBalance,
        bool _liquidityCreated,
        address _liquidityPool
    ) {
        return (
            totalTokensDistributed,
            totalParticipants,
            treasuryBalance,
            liquidityCreated,
            liquidityPool
        );
    }

    /**
     * @notice Get token balance of contract
     */
    function getTokenBalance() external view returns (uint256) {
        return basedToken.balanceOf(address(this));
    }
}
