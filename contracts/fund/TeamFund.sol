pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

contract TeamFund is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public unlockTime = 1640721600; // 2021-12-28 20:00:00 UTC

    function withdraw(
        address token,
        uint256 amount,
        address to
    ) public onlyOwner {
        require(block.timestamp >= unlockTime, "locked");
        IERC20(token).safeTransfer(to, amount);
    }


}