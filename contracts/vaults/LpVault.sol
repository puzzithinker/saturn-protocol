pragma solidity ^0.6.0;

import "./BaseVault.sol";
import "../interfaces/IUniswapV2Router01.sol";


contract LpVault is BaseVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public lpToken;
    address public token0;
    address public token1;
    uint256 public farmMasterChefPid;

    address[] public path0;
    address[] public path1;

    address public farmToken;
    address public farmMasterChef;
    address public farmRouter;
    
    address public feeReceiver;
    uint256 public feeRate = 0;

    uint256 public freePeriod = 0;
    uint256 public exitFeeRate = 0;

    constructor(
        string memory _name,
        string memory _symbol,
        address _token,
        address _token0,
        address _token1,
        address _farmToken,
        address _farmMaster,
        address _farmRouter,
        address[] memory _path0,
        address[] memory _path1,
        uint256 _farmChefPid,
        address _feeReceiver
    ) 
        public 
        BaseVault(
            _name,
            _symbol,
            _token
        )
    {
        lpToken = _token;
        farmMasterChefPid = _farmChefPid;
        feeReceiver = _feeReceiver;
        token0 = _token0;
        token1 = _token1;
        path0 = _path0;
        path1 = _path1;
        farmToken = _farmToken;
        farmMasterChef = _farmMaster;
        farmRouter = _farmRouter;
        IERC20(lpToken).approve(farmMasterChef, uint256(-1));
        IERC20(farmToken).approve(farmRouter, uint256(-1));
        IERC20(_token).approve(farmRouter, uint256(-1));
        IERC20(_token0).approve(farmRouter, uint256(-1));
        IERC20(_token1).approve(farmRouter, uint256(-1));
    }

    function _harvest() internal override {
        (uint256 stakeAmount, ) = IFarmMasterChef(farmMasterChef).userInfo(farmMasterChefPid, address(this));
        if (stakeAmount > 0) {
            IFarmMasterChef(farmMasterChef).withdraw(farmMasterChefPid, 0);
        }

        uint256 farmAmount = IERC20(farmToken).balanceOf(address(this));
        if (farmAmount > 0) {
            IERC20(farmToken).safeTransfer(feeReceiver, farmAmount.mul(feeRate).div(100));
            farmAmount = IERC20(farmToken).balanceOf(address(this));

            if (path0.length > 0) {
                IUniswapV2Router01(farmRouter).swapExactTokensForTokens(farmAmount.div(2), 1, path0, address(this), block.timestamp);
            }
            if (path1.length > 0) {
                IUniswapV2Router01(farmRouter).swapExactTokensForTokens(farmAmount.div(2), 1, path1, address(this), block.timestamp);
            }
            IUniswapV2Router01(farmRouter).addLiquidity(token0, token1, 
                IERC20(token0).balanceOf(address(this)), 
                IERC20(token1).balanceOf(address(this)), 
                1, 1, address(this), block.timestamp);
        }
    }

    function _invest() internal override {
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        if (lpAmount > 0) {
            IFarmMasterChef(farmMasterChef).deposit(farmMasterChefPid, lpAmount);
        }

    }

    function _exit() internal override {
        IFarmMasterChef(farmMasterChef).emergencyWithdraw(farmMasterChefPid);
    }

    function _exitSome(uint256 _amount) internal override {
        IFarmMasterChef(farmMasterChef).withdraw(farmMasterChefPid, _amount);
    }

    function _withdrawFee(uint256 _withdrawAmount, uint256 _lastDepositTime) internal override returns (uint256) {
        if (_lastDepositTime.add(freePeriod) <= block.timestamp) {
            return 0;
        }
        uint256 feeAmount = _withdrawAmount.mul(exitFeeRate).div(1000);
        IERC20(lpToken).safeTransfer(feeReceiver, feeAmount);
        return feeAmount;
    }

    function _totalTokenBalance() internal view override returns (uint256) {
        (uint256 stakeAmount, ) = IFarmMasterChef(farmMasterChef).userInfo(farmMasterChefPid, address(this));
        return IERC20(lpToken).balanceOf(address(this)).add(stakeAmount);
    }

    function setPath(address[] calldata _path0, address[] calldata _path1) public onlyOperator {
        path0 = _path0;
        path1 = _path1;
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


interface IFarmMasterChef {
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256); 
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
}