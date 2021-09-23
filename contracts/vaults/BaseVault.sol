pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import "../interfaces/IMasterChef.sol";
import "../interfaces/IVault.sol";
import "../utils/TokenConverter.sol";


abstract contract BaseVault is IVault, ERC20, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public wantToken;

    address public saturnMasterChef;
    uint256 public saturnStakePid;

    address public operator;
    bool public emergencyStop;  // stop deposit and invest, can only withdraw

    bool public isDepositHarvest;
    bool public isDepositInvest;
    bool public isWithdrawHarvest;
    bool public isWithdrawInvest;
    uint256 public lastInvestTime;

    mapping(address => uint256) private _shareBalances;
    mapping(address => uint256) public lastDepositTimes;
    
    mapping(address => uint256) public totalDepositAmounts;
    mapping(address => uint256) public totalWithdrawAmounts;
    mapping(address => uint256) public lastActionTimes;
    mapping(address => uint256) public lastActionTokenBalances;
    uint256 totalDepositAmount;
    uint256 totalWithdrawAmount;

    constructor(
        string memory _name,
        string memory _symbol,
        address _wantToken
    ) public ERC20(_name, _symbol) {
        wantToken = _wantToken;
        operator = msg.sender;
    }

    modifier onlyOperator {
        require (msg.sender == operator || msg.sender == owner(), "no operator");

        _;
    }

    modifier onlyEOA {
        require (msg.sender == tx.origin, "no user");

        _;
    }

    // ==============  VIRTUAL FUNCTIONS ===============
    
    function _harvest() internal virtual;
    function _invest() internal virtual;
    function _exit() internal virtual;
    function _exitSome(uint256 _amount) internal virtual;
    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal virtual returns (uint256);
    function _totalTokenBalance() internal view virtual returns (uint256);

    // =================  PUBLIC FUNCTIONs ===============

    function reinvest() external override onlyEOA {
        _harvest();
        if (!emergencyStop) {
            _invest();
            lastInvestTime = block.timestamp;
        }
    }

    function deposit(uint256 amount) external override onlyEOA {
        require(!emergencyStop, "emergencyStop");
        if (isDepositHarvest) {
            _harvest();
        }
        
        uint256 shareAmount = amount;
        if (totalSupply() > 0 && _totalTokenBalance() > 0) {
            shareAmount = amount.mul(totalSupply()).div(_totalTokenBalance());
        }
        
        _mint(address(this), shareAmount);
        IMasterChef(saturnMasterChef).deposit(msg.sender, saturnStakePid, shareAmount);
        _shareBalances[msg.sender] = _shareBalances[msg.sender].add(shareAmount);
        lastDepositTimes[msg.sender] = block.timestamp;
        
        IERC20(wantToken).safeTransferFrom(msg.sender, address(this), amount);
        if (isDepositInvest) {
            _invest();
            lastInvestTime = block.timestamp;
        }

        lastActionTimes[msg.sender] = block.timestamp;
        lastActionTokenBalances[msg.sender] = tokenBalanceOf(msg.sender);
        totalDepositAmounts[msg.sender] = totalDepositAmounts[msg.sender].add(amount);
        totalDepositAmount = totalDepositAmount.add(amount);
    }

    function withdraw(uint256 amount) public override onlyEOA {
        if (isWithdrawHarvest) {
            _harvest();
        }
        uint256 shareAmount = amount.mul(totalShareBalance()).div(_totalTokenBalance());
        
        IMasterChef(saturnMasterChef).withdraw(msg.sender, saturnStakePid, shareAmount);
        _shareBalances[msg.sender] = _shareBalances[msg.sender].sub(shareAmount);
        _burn(address(this), shareAmount);

        uint256 localBalance = IERC20(wantToken).balanceOf(address(this));
        if (amount > localBalance) {
            uint256 withdrawAmount = amount.sub(localBalance);
            _exitSome(withdrawAmount);
        }
            
        uint256 withdrawFee = _withdrawFee(amount, lastDepositTimes[msg.sender]);
        IERC20(wantToken).safeTransfer(msg.sender, amount.sub(withdrawFee));

        if (isWithdrawInvest) {
            _invest();
            lastInvestTime = block.timestamp;
        }  

        lastActionTimes[msg.sender] = block.timestamp;
        lastActionTokenBalances[msg.sender] = tokenBalanceOf(msg.sender);
        totalWithdrawAmounts[msg.sender] = totalWithdrawAmounts[msg.sender].add(amount);
        totalWithdrawAmount = totalDepositAmount.add(amount);    
    }

    function withdrawAll() external override onlyEOA {
        withdraw(tokenBalanceOf(msg.sender));
    }

    // ============= GOV ===============================

    function setSaturnStakePid(address _saturnMasterChef, uint256 _stakePid) public onlyOwner {
        saturnMasterChef = _saturnMasterChef;
        saturnStakePid = _stakePid;
        _approve(address(this), saturnMasterChef, 10**60);
    }

    function setEmergencyOperator(address _op) public onlyOwner {
        operator = _op; 
    }

    function setIfHarvestInvest(
        bool _isDepositHarvest, 
        bool _isDepositInvest,
        bool _isWithdrawHarvest,
        bool _isWithdrawInvest
    ) public onlyOperator {
        isDepositHarvest = _isDepositHarvest;
        isDepositInvest = _isDepositInvest;
        isWithdrawHarvest = _isWithdrawHarvest;
        isWithdrawInvest = _isWithdrawInvest;
    }

    // ============  EMERGENCY GOV =======================

    function stop() public virtual onlyOperator {
        emergencyStop = true;
        _exit();
    }

    function start() public virtual onlyOperator {
        emergencyStop = false;
    }

    // ===================== VIEW ========================== 
    function tokenBalanceOf(address user) public view override returns (uint256) {
        if (totalSupply() == 0) {
            return 0;
        }
        return _totalTokenBalance().mul(shareBalanceOf(user)).div(totalShareBalance());
    }

    function totalTokenBalance() public view override returns (uint256) {
        return _totalTokenBalance(); 
    }

    function shareBalanceOf(address user) public view override returns (uint256) {
        return _shareBalances[user];
    }

    function totalShareBalance() public view override returns (uint256) {
        return totalSupply();
    }

}


