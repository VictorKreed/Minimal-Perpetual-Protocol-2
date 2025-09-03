// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ILPManager} from "./interfaces/ILPManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PriceOracle.sol";


contract PositionManager is PriceOracle, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    uint256 public totalActivePositions; // Track total active positions, used to restrict LP withdrawals during active trades
    mapping(address => Position) public traderOpenPositionDetails ; // Store user positions
    
    uint256 public maximumLeverage = 5; // 5x
    uint256 public liquidationThreshold = 80; // 80% loss triggers liquidation
    uint256 public openingFee = 2; // USDT
    uint256 public closingFee = 2; // USDT
    bool TradeisActive;

    mapping(address depositor => Deposit) private userDeposits;
    uint256 public totalDeposits;
    mapping(address => bool) public isAdmin;

    IERC20 public immutable liquidityToken; //USDT
    // Reference to LPManager contract
    ILPManager public immutable lpManager;
    
    /*
    User deposit tracking
    */
struct Deposit {
    uint256 amount;
    }

/*
    Position types, going long (betting increase) or short (betting decrease)
*/
enum PositionType {
    LONG,
    SHORT
}

/*
    Position struct to track individual trader positions
*/
  struct Position {
        uint256 collateralAmount;
        uint256 leveragemultiplier;
        uint256 nativeTokenCurrentPrice; //ETH price at opening time
        uint256 positionsize;  // collateral * leverage  
        address owner;
        uint openedAt;
        PositionType positionType;
        bool positionActive;      
    }

   /*
    * @dev Events for logging key actions
    */
    event DepositCreated(address indexed user, uint256 amount, uint256 depositedAt);
    event PositionOpened(address indexed user, uint256 collateralAmount, uint256 positionSize, PositionType positionType, uint256 leverage, uint256 currentETHprice);
    event PositionClosed(address indexed user, uint256 collateralAmount, uint256 positionSize, int256 pnl, uint256 closingPrice);
    event PositionLiquidated(address indexed user, uint256 liquidationPrice, uint256 remainingCollateral);

    constructor(
        address _liquidityToken, //USDT
        address _lpManager, 
        address admin1,
        address admin2
    ) {
        liquidityToken = IERC20(_liquidityToken);
        lpManager = ILPManager(_lpManager);
        isAdmin[admin1] = true;
        isAdmin[admin2] = true;
    }

       /*
        * @dev Function for users to deposit collateral (USDT) into the contract
        * @param _amount Amount of USDT to deposit
        * Emits DepositCreated event
        */
    function deposit(uint256 _amount) public {
        address trader = msg.sender;
        require(_amount > 0, "Deposit amount must be greater than zero");
         Deposit storage userDeposits_ = userDeposits[trader];
         //@note trader must approve contract externally to spend tokens or implement permit if supported by token
        IERC20(liquidityToken).safeTransferFrom(trader, address(this), uint256(_amount) );
        totalDeposits += _amount;
        userDeposits_.amount += _amount;
        emit DepositCreated(msg.sender, uint256(_amount), block.timestamp);
    }

       /*
        * @dev View function to get the deposited balance of a user
        * @param _depositor Address of the user
        * @return amount The amount of USDT deposited by the user
        */
    function getUserDeposit(address _depositor) public view returns (uint256) {
        return userDeposits[_depositor].amount;
     }


        /*
            * @dev Function for users to withdraw their deposited collateral (USDT) from the contract
            * @param _amount Amount of USDT to withdraw
            * Emits no event, but updates user deposit mapping and total deposits
            * Requirements:
            * - User must have sufficient deposited balance
            * - User must not have an active trading position
            */
  function withdraw(uint256 _amount) public {
          address trader = msg.sender;
        require(traderOpenPositionDetails[msg.sender].positionActive == false, "User must close position before withdrawing");
          Deposit storage userDeposits_ = userDeposits[msg.sender];
        require(userDeposits_.amount >= _amount, "Insufficient deposit balnce");
        totalDeposits -= _amount;
        userDeposits_.amount -= _amount;
        IERC20(liquidityToken).safeTransfer(trader, _amount);
         delete traderOpenPositionDetails[trader];
    }

/**
     * @dev Function to open a new trading position
     * @param collateralAmount Amount of collateral to deposit (in USDT)
     * @param leverageMultiplier Leverage multiplier (e.g., 2 for 2x)
     * @param positionType Type of position: LONG or SHORT
     * @notice Opening fee is deducted from collateral amount
     * Emits PositionOpened event
     */
    function openPosition(
        uint256 collateralAmount, //trader should keep in mind that opening fee is subtracted from collateral amount when opening a position
        uint256 leverageMultiplier, 
        PositionType positionType
    ) external nonReentrant {
        address trader = msg.sender;
        require(TradeisActive == true, "Trading is Paused or Closed, wait till Trading is resumed by platform");
        require(!traderOpenPositionDetails[trader].positionActive, "Position already active for this user");
        require(leverageMultiplier <= maximumLeverage && leverageMultiplier > 0, "Invalid leverage");
        require(collateralAmount > openingFee, "Collateral amount must be greater than opening fee");

        // Check user has enough collateral
        collateralAmount = getUserDeposit(trader);
        require(collateralAmount >= collateralAmount, "Insufficient collateral balance");
       

        IERC20(liquidityToken).safeTransfer(address(lpManager),  collateralAmount); 


         userDeposits[trader].amount -=  collateralAmount;
        lpManager.updateYields(collateralAmount);
        TradeisActive = true; 

        // Get current ETH price
        (int256 ethPrice,) = getChainlinkDataFeedLatestAnswer();
        require(ethPrice > 0, "Invalid ETH price");
        
        uint256 currentEthPrice = uint256(ethPrice);
        uint256 positionSize = (collateralAmount - openingFee) * leverageMultiplier; //in USDT
        
        // Create and store position
         traderOpenPositionDetails[trader] = Position({
            collateralAmount: collateralAmount,  //amount deposited
            leveragemultiplier : leverageMultiplier, //leverage taken
            nativeTokenCurrentPrice: currentEthPrice, //ETH price at opening time in USD
            positionsize: positionSize,  //amount deposited * leverage in USDT 
            owner: trader,
            openedAt: block.timestamp,
            positionType: positionType,
            positionActive: true
        });

        totalActivePositions += 1;

        emit PositionOpened(msg.sender,collateralAmount, positionSize, positionType, leverageMultiplier, currentEthPrice);
    }

    /**
     * @dev Function to close an existing trading position
     * Calculates P&L based on current price and position details
     * Transfers collateral + P&L back to trader, deducting closing fee
     * Updates LP yields accordingly
     * Emits PositionClosed event
     */
    function closePosition() external nonReentrant {
        address trader = msg.sender;
        require(TradeisActive == true, "Trading is Paused or Closed, wait till Trading is resumed by platform");
        require(traderOpenPositionDetails[trader].positionActive == true, "No active position to close");
        
        Position storage userPosition = traderOpenPositionDetails[trader];

        // Get current ETH price
        (int256 ethPrice,) = getChainlinkDataFeedLatestAnswer();
        require(ethPrice > 0, "Invalid ETH price");
        uint256 currentEthPrice = uint256(ethPrice);
        
        // Calculate Profit or Loss of trader
        int256 pnl = _calculatePnL(userPosition, currentEthPrice);
        
        int256 AmountToWithdrawForTrader =  int256(userPosition.collateralAmount) + pnl;
        require(AmountToWithdrawForTrader > 0, "Negative or Empty balnce, Trader has lost all collateral and profits");

        lpManager.approvePostionTradeContract();
        IERC20(liquidityToken).safeTransferFrom(address(this), address(lpManager), (uint256(AmountToWithdrawForTrader) - closingFee));
        lpManager.unApprovePostionTradeContract();
       
         traderOpenPositionDetails[trader].positionActive = false;

         withdraw(uint256(AmountToWithdrawForTrader));
         totalActivePositions -= 1;
        emit PositionClosed(msg.sender, userPosition.collateralAmount , userPosition.positionsize , pnl , currentEthPrice); 
    }

    /**
     * @dev Function to liquidate a trader's position if it meets liquidation criteria
     * Liquidation occurs if P&L drops below the liquidation threshold (e.g., 80% loss)
     * Remaining collateral after losses is returned to trader
     * Position is closed and marked inactive
     * Emits PositionLiquidated event
     */
    function liquidatePosition(address user) external nonReentrant {
        require(traderOpenPositionDetails[user].positionActive == true, "No active position to liquidate");
        
        Position storage userPosition = traderOpenPositionDetails[user];
        
        // Get current ETH price
        (int256 ethPrice,) = getChainlinkDataFeedLatestAnswer();
        require(ethPrice > 0, "Invalid ETH price");
        uint256 currentEthPrice = uint256(ethPrice);
        
       // Calculate current P&L
        int256 pnl = _calculatePnL(userPosition, currentEthPrice);
        
        // Check if liquidation is valid (80% loss)
        uint256 collateralUsed = userPosition.collateralAmount;
        uint256 liquidationThresholdAmount = (collateralUsed * liquidationThreshold) / 100;
        

        require(pnl <= -int256(liquidationThresholdAmount), "Position not eligible for liquidation");
        
        // Calculate remaining collateral after loss
        uint256 totalLoss = uint256(-pnl);
        uint256 remainingCollateral = totalLoss < collateralUsed ? collateralUsed - totalLoss : 0;
        
        
        // Clean up position
         traderOpenPositionDetails[user].positionActive = false;
        totalActivePositions -= 1;
        delete  traderOpenPositionDetails[user];

        emit PositionLiquidated(user, currentEthPrice, remainingCollateral);
    }


/**
     * @dev Internal function to calculate Profit or Loss (P&L) for a position
     * @param position The Position struct containing position details
     * @param currentPrice The current price of the underlying asset (ETH)
     * @return pnl The calculated P&L, positive for profit and negative for loss
     */
    function _calculatePnL(Position memory position, uint256 currentPrice) internal pure returns (int256) {
        uint256 openedPrice = position.nativeTokenCurrentPrice;
        uint256 leverage = position.leveragemultiplier;

        if (position.positionType == PositionType.LONG) {
            // Long position: profit when price goes up
            if (currentPrice > openedPrice) {
                int256 priceGain = int256(currentPrice) - int256(openedPrice);
                int256 traderprofit = ((int256(leverage) * priceGain ) / int256(openedPrice));
                return (traderprofit);
            } else {
                int256 priceLoss = int256(currentPrice) - int256(openedPrice);
                int256 traderLoss = ((int256(leverage) * priceLoss ) / int256(openedPrice));
                return (traderLoss);
            }
        } else {
            // Short position: profit when price goes down
            if (currentPrice < openedPrice) {
                uint256 priceGain = openedPrice - currentPrice;
                uint256 profit = (leverage * priceGain) / openedPrice;
                return int256(profit);
            } else {
               int256 priceLoss = int256(openedPrice) - int256(currentPrice);
                int256 traderLoss = ((int256(leverage) * priceLoss ) / int256(openedPrice));
                return (traderLoss);  
            }
        }
    }

  /**
     * @dev View function to get current P&L for a user's position
     * @param user Address of the trader
     * @return pnl Current Profit or Loss, positive for profit and negative for loss
     * @notice Returns 0 if no active position
     */
    function getPositionPnL(address user) external view returns (int256) {
        require(traderOpenPositionDetails[user].positionActive == true, "No active position");
        
        Position memory userPosition =  traderOpenPositionDetails[user];
        (int256 ethPrice,) = getChainlinkDataFeedLatestAnswer();
        uint256 currentPrice = uint256(ethPrice);
        
        return _calculatePnL(userPosition, currentPrice);
    }

    /**
     * @dev View function to check if a user's position is eligible for liquidation
     * @param user Address of the trader
     * @return True if position can be liquidated, false otherwise
     * @notice Liquidation occurs if P&L drops below the liquidation threshold (e.g., 80% loss)
     */
    function isLiquidationValid(address user) public view returns (bool) {
        if (! traderOpenPositionDetails[user].positionActive) return false;
        
        Position memory userPosition = traderOpenPositionDetails[user];
        (int256 ethPrice,) = getChainlinkDataFeedLatestAnswer();
        uint256 currentPrice = uint256(ethPrice);
        
        int256 pnl = _calculatePnL(userPosition, currentPrice);
        uint256 collateralUsed = userPosition.collateralAmount;
        uint256 liquidationThresholdAmount = (collateralUsed * liquidationThreshold) / 100;
        
        return pnl <= -int256(liquidationThresholdAmount);
    }

    /*
     * @dev Admin function to set the maximum leverage allowed
     * @param _maxLeverage New maximum leverage (e.g., 5 for 5x)
     * @notice Only callable by admin addresses
     */
    function setMaximumLeverage(uint256 _maxLeverage) external  {
        require(isAdmin[msg.sender] == true, "Only Admin");
        maximumLeverage = _maxLeverage;
    }
    
    /**
     * @dev Admin function to set the liquidation threshold percentage
     * @param _threshold New liquidation threshold (e.g., 80 for 80%)
     * @notice Threshold must be between 1 and 95 to avoid extreme values
     */
    function setLiquidationThreshold(uint256 _threshold) external {
        require(isAdmin[msg.sender] == true, "Only Admin");
        require(_threshold <= 95, "Threshold still high");
        liquidationThreshold = _threshold;
    }

  /**
     * @dev View function to check if any trading positions are currently active
     * @return True if there are active trading positions, false otherwise
     */
    function TradeStatus() public view returns (bool){
        return TradeisActive;
    }

/**
     * @dev Admin function to close trading status when all positions are closed
     * @notice Ensures no active positions before setting TradeisActive to false
     */
    function closeTradeStatus()public {
        require(isAdmin[msg.sender] == true, "Only Admin");
        require(totalActivePositions == 0, "One or more trades are still ongoing");
        TradeisActive = false;
    }
}