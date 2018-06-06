pragma solidity ^0.4.23;

// ERC223 token interface
contract ERC223 {
    function transfer(address to, uint amount, bytes data) public returns (bool ok);

    function transferFrom(address from, address to, uint256 amount, bytes data) public returns (bool ok);

    function transfer(address to, uint amount, bytes data, string custom_fallback) public returns (bool ok);

    function transferFrom(address from, address to, uint256 amount, bytes data, string custom_fallback) public returns (bool ok);

    event ERC223Transfer(address indexed from, address indexed to, uint amount, bytes data);

    event ReceivingContractTokenFallbackFailed(address indexed from, address indexed to, uint amount);
}