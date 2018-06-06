pragma solidity ^0.4.11;

import "./lib/SafeMath.sol";
import "./HNA.sol";
import './Controlled.sol';


contract WhitelistSale is Controlled {

    using SafeMath for uint256;

    HNA public hnaToken;

    // Amount of HNA received per ETH
    uint256 public hnaPerEth;

    // Sales start at this timestamp
    uint256 public initialTimestamp;

    // The sale goes on through 6 days.
    // Each day, users are allowed to buy up to a certain (cummulative) limit of HNA.

    // This mapping stores the addresses for whitelisted users
    mapping(address => bool) public whitelisted;

    // Used to calculate the current limit
    mapping(address => uint256) public bought;

    // The initial values allowed for sale
    uint256 public maxSale;

    // Forwarding address
    address public receiver;

    event LogWithdrawal(uint256 _value);
    event LogBought(uint orderInHNA);
    event LogUserAdded(address user);
    event LogUserRemoved(address user);

    function WhitelistSale (
        HNA _hnaToken,
        uint256 _initialTimestamp,
        address _receiver
    )
        Controlled()
    {
        hnaToken        = _hnaToken;
        initialTimestamp = _initialTimestamp;
        receiver         = _receiver;

        hnaPerEth       = 5000;
        maxSale   = 10000 ether;
    }

    // Withdraw HNA (only controller)
    function withdrawHNA(uint256 _value) onlyController returns (bool ok) {
        return withdrawToken(hnaToken, _value);
    }

    // Withdraw any HNA token (just in case)
    function withdrawToken(address _token, uint256 _value) onlyController returns (bool ok) {
        return HNA(_token).transfer(controller,_value);
        LogWithdrawal(_value);
    }

    // Change address where funds are received
    function changeReceiver(address _receiver) onlyController {
        require(_receiver != 0);
        receiver = _receiver;
    }

    // Calculate which day into the sale are we.
    function getDay() constant returns (uint256) {
        return block.timestamp.sub(initialTimestamp).div(1 days);
    }

    modifier onlyIfActive {
        require(getDay() >= 0);
        require(getDay() < 6);
        _;
    }

    function buy(address beneficiary) payable onlyIfActive {
        require(beneficiary != 0);
        require(whitelisted[msg.sender]);

        uint day = getDay();
        uint256 allowedForSender = maxSale - bought[msg.sender];

        if (msg.value > allowedForSender) revert();

        uint256 balanceInHNA = hnaToken.balanceOf(address(this));

        uint orderInHNA = msg.value * hnaPerEth;
        if (orderInHNA > balanceInHNA) revert();

        bought[msg.sender] = bought[msg.sender].add(msg.value);
        hnaToken.transfer(beneficiary, orderInHNA);
        receiver.transfer(msg.value);

        LogBought(orderInHNA);
    }

    // Add a user to the whitelist
    function addUser(address user) onlyController {
        whitelisted[user] = true;
        LogUserAdded(user);
    }

    // Remove an user from the whitelist
    function removeUser(address user) onlyController {
        whitelisted[user] = false;
        LogUserRemoved(user);
    }

    // Batch add users
    function addManyUsers(address[] users) onlyController {
        require(users.length < 10000);
        for (uint index = 0; index < users.length; index++) {
             whitelisted[users[index]] = true;
             LogUserAdded(users[index]);
        }
    }

    function() payable {
        buy(msg.sender);
    }
}