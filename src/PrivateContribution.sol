pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "erc20/erc20.sol";
import "ds-stop/stop.sol";

contract PrivateContribution is DSStop {
    using SafeMath for uint256;

    uint256 public exchangeRate = 1000;

    ERC20 public token;

    constructor(address _token) public {
        token = ERC20(_token);
    }

    function () public payable {
      proxyPayment(msg.sender);
    }

    function proxyPayment(address _th) public payable stoppable returns (bool) {
      require(_th != 0x0);

      owner.transfer(msg.value);

      uint256 tokenAmount = msg.value.mul(exchangeRate);
      require(token.transfer(_th, tokenAmount));

      NewSale(_th, msg.value, tokenAmount);
      return true;
    }

    function changeExchangeRate(uint256 _newExchangeRate) auth stoppable public {
        uint256 oldExchangeRate = exchangeRate;
        exchangeRate = _newExchangeRate;
        emit NewExchangeRate(oldExchangeRate, _newExchangeRate);
    }

    event NewExchangeRate(uint256 _oldExchangeRate, uint256 _newExchangeRate);

    event NewSale(address indexed _th, uint256 _amount, uint256 _tokens);
}