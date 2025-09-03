// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPositionManager} from "./interfaces/IPosition.sol";
/*
    Liquidity Providers Contract
    - Manages Liquidity Providers (LPs) who deposit USDT to provide liquidity for traders.
    - Tracks LP shares, ownership percentages, and yields from trading activities.
    - Allows LPs to deposit, withdraw, and earn yields based on trading profits/losses.
    - Interacts with PositionManager contract to ensure trades are settled before LP withdrawals.
*/
contract LPManager is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable liquidityToken; //USDT

    address positionTradeContract; //same as the deployed PositionManager contract Traders will interact with, to pay LPs their yields
    
    // Total worth of USDT deposited by LPs
    uint256 public totalShares;
    
    // Current  yield earned from traders 
    //notice this is different from totalShares, as it isolates collateral and profits/losses from trading activities
    //but is still part of the total pool i.e(totalShares + totalYield ) value LPs can withdraw from, and pay trader wins from and receive trader losses into
    uint256 public totalYields;
    
    // LP tracking struct
    struct LiquidityProvider {
        uint256 shares;           // Number of shares(individual tokens) owned
        uint256 ownershipPercent; // Percentage of pool owned (stored as basis points: 10000 = 100% for better precision)
        //incase of confusion, basisPoint/100 gives back real world percentage
    }
    
    //contract administrators
    mapping(address => bool) public isContractAdmin;
    
    // Mapping of LP address to their info
    mapping(address => LiquidityProvider) public liquidityProviders;
    
    constructor(address _liquidityToken  , address contractAdmin1, address contractAdmin2 ) {
        require(_liquidityToken != address(0), "Invalid token address");
        liquidityToken = IERC20(_liquidityToken);
        isContractAdmin[contractAdmin1] = true;
        isContractAdmin[contractAdmin2] = true;

    }
    
    /**
     * @dev Public deposit function for LPs to deposit tokens and receive shares
     * @notice Minimum deposit of 10,000 USDT required
     * Calculates and updates ownership percentage upon each deposit
     * Emits Deposit event
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount >= 10000, "At least 10,000 USDT is required to be a Liquidity Provider");
        
        // Transfer tokens from LP to contract 
        liquidityToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate ownership percentage before updating totals
        uint256 ownershipPercent = _calculateOwnershipPercent(amount);
        
        // Update LP's shares and ownership percentage
        liquidityProviders[msg.sender].shares += amount;
        liquidityProviders[msg.sender].ownershipPercent = ownershipPercent;
        
        // Update total shares
        totalShares += amount;
    
        emit Deposit(msg.sender, amount, ownershipPercent);
    }
    
    /**
     * @dev Internal function to calculate ownership percentage for new depositor
     * @notice Uses basis points (10000 = 100%) for precision
     * @param currentDepositAmount Amount being deposited by the LP
     * @return Updated ownership percentage in basis points
     */
    function _calculateOwnershipPercent(uint256 currentDepositAmount) internal view returns (uint256) {
        if (totalShares == 0) {  
            return 10000; // 10,000 basis points = 100% for first depositor
        }
            
        // Calculate new percentage for new or existing LP: 
        uint256 newTotalShares = totalShares + currentDepositAmount;
        uint256 totalDepositBalance = currentDepositAmount + liquidityProviders[msg.sender].shares; //this line ensures already existing LPs incase depositng more, get their previous shares counted in the new ownership percentage calculation.

        return (totalDepositBalance * 10000) / newTotalShares;
    }
    
    /**
     * @dev View function to get current updated ownership percentage for any LP
     * @param lp Address of the liquidity provider
     * @return Current ownership percentage in basis points
     * @notice Multiplies before dividing to avoid precision loss
     */
    function getCurrentOwnershipPercent(address lp) public view returns (uint256) {
        if (totalShares == 0) return 0;
        // Fix: multiply first, then divide to avoid precision loss  
        return (liquidityProviders[lp].shares * 10000) / totalShares;
    }
    
    /**
     * @dev View function to get total shares (used by external contracts)
     */
    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }
    
    /**
     * @dev Withdraw function for LPs
     * @notice can only be called when all trading positions are confirmed closed
     * Uses current ownership percentage to calculate withdrawable amount from total assets
     * Deducts LP's portion of yields from total yields
     * Resets LP's shares and ownership percentage after withdrawal
     */
    function withdrawAll() external nonReentrant {
        bool isTradeActive = IPositionManager(positionTradeContract).TradeStatus();

        require(  isTradeActive == false , "One or more Trade positions are still active");
        require(liquidityProviders[msg.sender].shares > 0, "No shares to withdraw");
        
        // Calculate total pool value (shares + yields from trading)
        uint256 totalPoolValue = totalShares + totalYields;
        
        // Calculate LP's withdrawable amount based on their up-to-date percentage
        uint256 currentPercent = getCurrentOwnershipPercent(msg.sender);
        uint256 withdrawableAmount = (currentPercent * totalPoolValue) / 10000;
        
        // Calculate LP's portion of yields to deduct
        uint256 yieldsToDeduct = (currentPercent * totalYields) / 10000;
        
        // Update state before transfer
        totalShares -= liquidityProviders[msg.sender].shares;
        totalYields -= yieldsToDeduct;
        
        // Reset LP position
        delete liquidityProviders[msg.sender];
        
        // Transfer tokens back to LP
        liquidityToken.safeTransfer(msg.sender, withdrawableAmount);
        
        emit Withdraw(msg.sender, withdrawableAmount, currentPercent);
    }
    
    /**
     * @dev Function to update total yields (called by trading contract when trades settle)
     * This is where trader collateral Amount, position opening and close Fee, Profit and Loss affects the LP pool
     */
    function updateYields(uint256 amount) external {
     require(msg.sender == positionTradeContract, "Only the trading contract can call this function");
        totalYields += amount;
        
        emit YieldsUpdated(amount, totalYields);
    } 

/*
    Administrative functions to manage trading contract address and approvals
*/
    function setPostionTradeContract( address newTradeContract) public {
        require(newTradeContract != address(0), "Invalid Address");
        require(isContractAdmin[msg.sender], "Only an Administrator can call this Function");
        positionTradeContract = newTradeContract;
    }
    
    /*
        * @dev Functions to approve/unapprove trading contract to spend liquidity tokens
        * Ensures only the designated trading contract can call these functions
        */
    function approvePostionTradeContract() public {
        require(msg.sender == positionTradeContract, "Only the trading contract can call this function");
        IERC20(liquidityToken).approve(positionTradeContract, type(uint256).max);
    }

       /*
        * @dev Function to unapprove trading contract from spending liquidity tokens
        * Ensures only the designated trading contract can call this function
        */
    function unApprovePostionTradeContract() public {
        require(msg.sender == positionTradeContract, "Only the trading contract can call this function");
        IERC20(liquidityToken).approve(positionTradeContract, 0);
    }

    
    event Deposit(address indexed lp, uint256 amount, uint256 ownershipPercent);
    event Withdraw(address indexed lp, uint256 amount, uint256 ownershipPercent);
    event YieldsUpdated(uint256 profits, uint256 newTotalYields);
}