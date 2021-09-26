pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IRewardMinter.sol";

contract RewardLocker is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct RewardVest {
        uint64 ts;
        uint192 amount;
    }


    address public token;
    mapping(address => mapping(uint256 => RewardVest)) public vests;
    mapping(address => uint256) public vestCounts;
    mapping(address => uint256) public totalClaims;

    event Mint(address indexed to, uint256 amount, uint256 ts);


    constructor(address _token) public {
        token = _token;
    }

    function mint(address to, uint256 amount, uint256 fromTs, uint256 pid) public {
        RewardVest memory v;
        v.ts = uint64(block.timestamp);
        v.amount = uint192(amount.div(60));
        vests[to][vestCounts[to]] = v;
        vestCounts[to] = vestCounts[to].add(1);
        IRewardMinter(token).mint(address(this), amount);
        IERC20(token).safeTransfer(to, amount.div(60));
        emit Mint(to, amount, block.timestamp);
    }

    function canClaim() public view returns(uint256) {
        uint256 i = vestCounts[msg.sender];
        if (i == 0) {
            return 0;
        }
        uint256 ret = 0;
        for (i = i - 1; i >= 0; i--) {
            RewardVest storage v = vests[msg.sender][i];
            if (uint256(v.ts).add(59 * 3 * 24 * 3600) < block.timestamp) {
                break;
            }
            ret = ret.add(block.timestamp.sub(v.ts).div(3 * 24 * 3600).mul(v.amount));
        }
        return ret;
    }


    function claim(uint256 amount) public {
        require(amount.add(totalClaims[msg.sender]) <= canClaim(), "not allow");
        totalClaims[msg.sender] = totalClaims[msg.sender].add(amount);
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    




}