pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IRewardMinter.sol";

contract RewardLocker {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct RewardVest {
        uint64 ts;
        uint192 amount;
    }

    uint256 public PERIOD = 3 * 24 * 3600;

    address public token;
    mapping(address => mapping(uint256 => RewardVest)) public vests;
    mapping(address => uint256) public vestCounts;
    mapping(address => uint256) public totalClaims;
    mapping(address => uint256) public totalLocked;

    mapping(address => bool) public ops; 
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not allow");

        _;
    }

    function setOwner(address _owner) public {
        require(owner == address(0) || msg.sender == owner, "no owner");
        owner = _owner;
    }

    function setOps(address _op) public onlyOwner {
        ops[_op] = true;
    }

    function setToken(address _token) public onlyOwner{
        token = _token;
    }

    function setPeriod(uint256 _period) public onlyOwner {
        PERIOD = _period;
    }
    

    function mint(address to, uint256 amount, uint256 pid) public {
        require(ops[msg.sender], "no ops");
        RewardVest memory v;
        v.ts = uint64(block.timestamp);
        v.amount = uint192(amount.div(60));
        vests[to][vestCounts[to]] = v;
        vestCounts[to] = vestCounts[to].add(1);
        IRewardMinter(token).mint(address(this), amount);
        IERC20(token).safeTransfer(to, amount.div(60));
        totalLocked[to] = totalLocked[to].add(amount.sub(amount.div(60)));
    }

    function currentLocked(address user) public view returns(uint256) {
        return totalLocked[user].sub(totalCanClaim(user));
    }

    function currentUnlocked(address user) public view returns(uint256) {
        return totalCanClaim(user).sub(totalClaims[user]);
    }

    function totalCanClaimAt(address user, uint256 ts) public view returns(uint256) {
        uint256 i = vestCounts[user];
        if (i == 0) {
            return 0;
        }
        uint256 ret = 0;
        for (i = i - 1; i >= 0; i--) {
            RewardVest storage v = vests[user][i];
            if (uint256(v.ts).add(59 * PERIOD) < ts) {
                break;
            }
            ret = ret.add(ts.sub(v.ts).div(PERIOD).mul(v.amount));
        }
        return ret;
    }

    function totalCanClaim(address user) public view returns(uint256) {
        return totalCanClaimAt(user, block.timestamp);
    }


    function claim(uint256 amount) public {
        require(amount.add(totalClaims[msg.sender]) <= totalCanClaim(msg.sender), "not allow");
        totalClaims[msg.sender] = totalClaims[msg.sender].add(amount);
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    




}