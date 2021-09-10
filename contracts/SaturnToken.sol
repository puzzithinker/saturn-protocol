pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


contract SaturnToken is ERC20, Ownable {

    mapping (address => uint256) public minterBalances;
    uint256 public totalMinterBalance;

    address public emergencyOperator;

    event SetMinter(address indexed minter, uint256 balance);

    constructor(
        string memory name, 
        string memory symbol,
        uint256 mintAmount
    ) public ERC20(name, symbol) {
        _mint(msg.sender, mintAmount);
        emergencyOperator = msg.sender;
    }

    // BEP20
    function getOwner() external view returns (address) {
        return owner();
    }

    
    // ================ GOVERNANCE ====================
    function mint(address recipient_, uint256 amount_)
        public
    {
        require(minterBalances[msg.sender] >= amount_, "no balance");
        minterBalances[msg.sender] = minterBalances[msg.sender].sub(amount_);
        totalMinterBalance = totalMinterBalance.sub(amount_);
        _mint(recipient_, amount_);
    }

    function burn(address account, uint256 amount)
        public
        onlyOwner
    {
        _burn(account, amount);
    }

    
    function setMinter(address _minter, uint256 _bal) public onlyOwner {
        totalMinterBalance = totalMinterBalance.sub(minterBalances[_minter]).add(_bal);
        minterBalances[_minter] = _bal;
        emit SetMinter(_minter, _bal);
    }

    function setEmergencyOperator(address _op) public onlyOwner {
        emergencyOperator = _op;
    }

    function emergencyRemoveMinter(address _minter) public {
        totalMinterBalance = totalMinterBalance.sub(minterBalances[_minter]);
        emit SetMinter(_minter, 0);
    }

}



