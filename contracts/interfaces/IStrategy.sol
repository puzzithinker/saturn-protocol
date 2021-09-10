pragma solidity 0.6.12;

interface IStrategy {
    
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawAll() external;

    function totalBalance() external view returns (uint256);
    
    
}