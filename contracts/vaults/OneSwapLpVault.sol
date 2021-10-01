pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import "../interfaces/IMasterChef.sol";
import "../interfaces/IUniswapV2Router01.sol";


contract OneSwapLpVault is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //===== base vault
    string private name_;
    string private symbol_;
    uint8 private decimals_;

    address public wantToken;

    address public saturnMasterChef;
    uint256 public saturnStakePid;

    address public owner;
    address public operator;
    bool public emergencyStop;  // stop deposit and invest, can only withdraw
    bool public initialized;

    bool public isDepositHarvest = true;
    bool public isDepositInvest = true;
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

    //======== lp vault ============================
    address public lpToken;
    address public token0;
    address public token1;
    uint256 public farmMasterChefPid;

    address[] public path0;
    address[] public path1;
    address[] public path2;

    address public farmToken;
    address public farmMasterChef;
    address public farmRouter;
    address public oneSwapRouter;
    
    address public feeReceiver;
    uint256 public feeRate = 0;

    uint256 public freePeriod = 0;
    uint256 public exitFeeRate = 0;

    constructor() public ERC20('Vault', 'VAULT') {

    }

    function init(
        string memory _name,
        string memory _symbol,
        address _token,
        address _token0,
        address _token1,
        address _farmToken,
        address _farmMaster,
        address _OneSwapRouter,
        address _farmRouter,
        address[] memory _path0,
        address[] memory _path1,
        address[] memory _path2,
        uint256 _farmChefPid,
        address _feeReceiver,
        address _owner
    ) public {
        require(!initialized, "init already");
        lpToken = _token;
        wantToken = _token;
        name_ = _name;
        symbol_ = _symbol;
        decimals_ = 18;
        farmMasterChefPid = _farmChefPid;
        feeReceiver = _feeReceiver;
        token0 = _token0;
        token1 = _token1;
        path0 = _path0;
        path1 = _path1;
        path2 = _path2;
        farmToken = _farmToken;
        farmMasterChef = _farmMaster;
        farmRouter = _farmRouter;
        oneSwapRouter = _OneSwapRouter;
        IERC20(lpToken).approve(farmMasterChef, uint256(-1));
        IERC20(farmToken).approve(farmRouter, uint256(-1));
        IERC20(_token).approve(farmRouter, uint256(-1));
        IERC20(_token0).approve(farmRouter, uint256(-1));
        IERC20(_token1).approve(farmRouter, uint256(-1));
        uint256 i;
        for (i = 0; i < _path2.length; i++) {
            IERC20(_path2[i]).approve(oneSwapRouter, uint256(-1));
        }
        owner = _owner;
        operator = _owner;
        initialized = true;
    }

    // ========= BASE function ==================

    modifier onlyOwner {
        require(msg.sender == owner, "no owner");

        _;
    }

    modifier onlyOperator {
        require (msg.sender == operator || msg.sender == owner, "no operator");

        _;
    }

    modifier onlyEOA {
        require (msg.sender == tx.origin, "no user");

        _;
    }

   
    // =================  PUBLIC FUNCTIONs ===============

    function reinvest() external {
        _harvest();
        if (!emergencyStop) {
            _invest();
            lastInvestTime = block.timestamp;
        }
    }

    function deposit(uint256 amount) external onlyEOA {
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

    function withdraw(uint256 amount) public onlyEOA {
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
        totalWithdrawAmount = totalWithdrawAmount.add(amount);    
    }

    function withdrawAll() external onlyEOA {
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

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
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

    function name() public view override returns (string memory) {
        return name_;
    }

    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    function decimals() public view override returns (uint8) {
        return decimals_;
    } 

    function tokenBalanceOf(address user) public view returns (uint256) {
        if (totalSupply() == 0) {
            return 0;
        }
        return _totalTokenBalance().mul(shareBalanceOf(user)).div(totalShareBalance());
    }

    function totalTokenBalance() public view returns (uint256) {
        return _totalTokenBalance(); 
    }

    function shareBalanceOf(address user) public view returns (uint256) {
        return _shareBalances[user];
    }

    function totalShareBalance() public view returns (uint256) {
        return totalSupply();
    }


    // ========== LP Vault internal function ====

    function _harvest() internal {
        (uint256 stakeAmount, ) = IOneSwapMaster(farmMasterChef).userInfo(farmMasterChefPid, address(this));
        if (stakeAmount > 0) {
            IOneSwapMaster(farmMasterChef).harvest(farmMasterChefPid, address(this));
        }

        uint256 farmAmount = IERC20(farmToken).balanceOf(address(this));
        if (farmAmount > 0) {
            IERC20(farmToken).safeTransfer(feeReceiver, farmAmount.mul(feeRate).div(100));
            farmAmount = IERC20(farmToken).balanceOf(address(this));

            if (path0.length > 0) {
                uint256 swapFarmAmount = farmAmount.div(2);
                if (path1.length == 0) {
                    swapFarmAmount = farmAmount;
                }
                IUniswapV2Router01(farmRouter).swapExactTokensForTokens(swapFarmAmount, 1, path0, address(this), block.timestamp);
            }
            if (path1.length > 0) {
                IUniswapV2Router01(farmRouter).swapExactTokensForTokens(farmAmount.div(2), 1, path1, address(this), block.timestamp);
                IUniswapV2Router01(farmRouter).addLiquidity(token0, token1, 
                    IERC20(token0).balanceOf(address(this)),
                    IERC20(token1).balanceOf(address(this)), 
                    1, 1, address(0), block.timestamp);
            }
            if (path2.length > 0) {
                uint256[] memory amounts = new uint256[](path2.length);
                for (uint256 i = 0; i < path2.length; i++) {
                    amounts[i] = IERC20(path2[i]).balanceOf(address(this));
                }
                IOneSwapRouter(oneSwapRouter).addLiquidity(amounts, 1, block.timestamp);   
            }
        }
    }

    function _invest() internal {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            IOneSwapMaster(farmMasterChef).deposit(farmMasterChefPid, lpAmount, address(this));
        }

    }

    function _exit() internal {
        IOneSwapMaster(farmMasterChef).emergencyWithdraw(farmMasterChefPid, address(this));
    }

    function _exitSome(uint256 _amount) internal {
        IOneSwapMaster(farmMasterChef).withdraw(farmMasterChefPid, _amount, address(this));
    }

    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal returns (uint256) {
        if (_lastDepositTime.add(freePeriod) <= block.timestamp) {
            return 0;
        }
        uint256 feeAmount = _withdrawAmount.mul(exitFeeRate).div(1000);
        IERC20(lpToken).safeTransfer(feeReceiver, feeAmount);
        return feeAmount;
    }

    function _totalTokenBalance() internal view returns (uint256) {
        (uint256 stakeAmount, ) = IOneSwapMaster(farmMasterChef).userInfo(farmMasterChefPid, address(this));
        return IERC20(lpToken).balanceOf(address(this)).add(stakeAmount);
    }

    function setPath(address[] calldata _path0, address[] calldata _path1, address[] calldata _path2) public onlyOperator {
        path0 = _path0;
        path1 = _path1;
        path2 = _path2;
        uint256 i;
        for (i = 0; i < _path2.length; i++) {
            IERC20(_path2[i]).approve(oneSwapRouter, uint256(-1));
        }
    }

    function setFeeReceiver(address _addr) public onlyOwner {
        feeReceiver = _addr;
    }

    function setFeeRate(uint256 _rate) public onlyOwner {
        require(_rate <= 30, "invalid rate");
        feeRate = _rate;
    }

    function setExitFeeRate(uint256 _rate) public onlyOwner {
        require(_rate <= 5, "invalid");
        exitFeeRate = _rate;
    }

    function setFreePeriod(uint256 _period) public onlyOwner {
        require(_period <= 25 days, "invalid period");
        freePeriod = _period;
    }
    
}


interface IOneSwapMaster {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 
    function deposit(uint256 _pid, uint256 _amount, address _to) external;
    function withdraw(uint256 _pid, uint256 _amount, address _to) external;
    function emergencyWithdraw(uint256 _pid, address _to) external;
    function harvest(uint256 pid, address to) external;
}

interface IOneSwapRouter {
    function addLiquidity(
        uint256[] memory amounts,
        uint256 minMintAmount,
        uint256 deadline
    ) external returns(uint256);
}