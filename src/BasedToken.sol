// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BasedToken
 * @notice The native token for the Based Daily Lottery
 * @dev Fixed supply ERC20 token designed for lottery rewards and liquidity
 *
 * Tokenomics:
 * - Total Supply: 1,000,000,000 (1 billion)
 * - Lottery Rewards: 600M (distributed via lottery contract)
 * - Liquidity Pool: 200M (used for DEX liquidity)
 * - Team/Future: 200M (locked in lottery contract for future use)
 *
 * All tokens are minted to the lottery contract which controls distribution
 */
contract BasedToken is ERC20, Ownable {
    
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Initialize the Based Token
     * @param _initialOwner Address to receive all tokens and ownership
     * @dev Mints entire supply to initial owner who should transfer to lottery
     */
    constructor(address _initialOwner) ERC20("Based Token", "BASED") Ownable(msg.sender) {
        require(_initialOwner != address(0), "Invalid owner address");
        
        // Mint entire supply to initial owner
        _mint(_initialOwner, TOTAL_SUPPLY);
        
        // Transfer ownership to initial owner for future flexibility
        transferOwnership(_initialOwner);
    }
}
