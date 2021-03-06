pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

contract IDOFund is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public token;
    uint256 public starttime;
    bool public startClaim;

    mapping(address => uint256) public totalAmounts;
    mapping(address => uint256) public totalClaims;

    address public operator;

    function set(address _token, uint256 _starttime) public onlyOwner {
        token = _token;
        starttime = _starttime;
    }

    function setStart(bool _start) public onlyOwner {
        startClaim = _start;
    }

    function setOperator(address _op) public onlyOwner {
        operator = _op;
    }

    function batchSetAmount(address[] calldata tos, uint256[] calldata amounts) public {
        require(msg.sender == operator, "no operator");
        uint256 i;
        require(tos.length == amounts.length);
        for (i = 0; i < tos.length; i++) {
            totalAmounts[tos[i]] = amounts[i];
        }
    }

    function freeAmountAt(address user, uint256 ts) public view returns(uint256) {
        if (starttime == 0 || totalAmounts[user] == 0 || ts <= starttime) {
            return 0;
        }
        uint256 dayCnt = ts.sub(starttime).div(1 days);
        uint256 idoAmount = totalAmounts[user];
        uint256 freeAmount = 0;
        if (dayCnt >= 1) {
            freeAmount = idoAmount.div(10);     // 10% at 1st day
        }
        if (dayCnt >= 15) {
            freeAmount = freeAmount.add(idoAmount.div(10));      // 10% at 15th day
        }
        if (dayCnt >= 30) {
            uint256 calcDayCnt = dayCnt.sub(30);    // 1.33% ervery day after 30th day
            if (calcDayCnt > 60) {
                calcDayCnt = 60;
            }
            freeAmount = freeAmount.add(idoAmount.mul(8).mul(calcDayCnt).div(600));
        }
        if (freeAmount > idoAmount) {
            freeAmount = idoAmount;
        }
        
        return freeAmount;
    }

    function lockedAmount(address user) public view returns(uint256) {
        return totalAmounts[user].sub(freeAmountAt(user, block.timestamp));
    }

    function unlockedAmount(address user) public view returns(uint256) {
        return freeAmountAt(user, block.timestamp).sub(totalClaims[user]);
    }

    function claim(uint256 amount) public {
        require(startClaim, "not started");
        require(amount <= unlockedAmount(msg.sender), "not allowed amount");
        totalClaims[msg.sender] = totalClaims[msg.sender].add(amount);
        IERC20(token).safeTransfer(msg.sender, amount);
    }


}