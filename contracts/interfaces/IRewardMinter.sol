pragma solidity 0.6.12;

interface IRewardMinter {
    function mint(address to, uint256 amount, uint256 fromTs, uint256 toTs) external;
    function mint(address to, uint256 amount) external;
}
