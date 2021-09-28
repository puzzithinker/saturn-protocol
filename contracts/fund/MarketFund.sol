pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

contract MarketFund is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function withdraw(
        address token,
        uint256 amount,
        address to,
        string memory reason
    ) public onlyOwner {
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawal(msg.sender, to, now, reason);
    }

    event Withdrawal(
        address indexed from,
        address indexed to,
        uint256 indexed at,
        string reason
    );

}