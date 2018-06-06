pragma solidity ^0.4.11;

/// @title AngelTokensHolder Contract
/// @author hackfisher
/// @dev This contract will hold the tokens of the angels and other parts.
///  Half of the Tokens will not be able to be collected until the contribution period ends.
///  period ends. The other half will not be able to be collected until 6 months after the contribution period ends.


//  collectable tokens
//   |                           |--------   vestedTokens rect
//   |                           |
//   |                           |
//   |                           |
//   |                           |
//   |    _______________________|
//   |   |
//   |   |
//   |   |
//   |   |
//   |   |
//   |   |
//   +===+=======================+------------> time
//     Contrib                 6 Months
//       End


import "./HNA.sol";
import "./Controlled.sol";
import "./HNAContribution.sol";
import "./lib/SafeMath.sol";


contract AngelTokensHolder is Controlled {
    using SafeMath for uint256;

    uint256 collectedTokens;
    HNAContribution contribution;
    HNA hna;

    function AngelTokensHolder(address _controller, address _contribution, address _hna) {
        controller = _controller;
        contribution = HNAContribution(_contribution);
        hna = HNA(_hna);
    }


    /// @notice The Owner will call this method to extract the tokens
    function collectTokens() public onlyController {
        uint256 balance = hna.balanceOf(address(this));
        uint256 total = collectedTokens.add(balance);

        uint256 finalizedTime = contribution.endTime();

        require(finalizedTime > 0);

        uint256 canExtract = total.div(2);

        if (getTime() > finalizedTime.add(months(6))) {
            canExtract = total;
        }

        canExtract = canExtract.sub(collectedTokens);

        if (canExtract > balance) {
            canExtract = balance;
        }

        collectedTokens = collectedTokens.add(canExtract);
        assert(hna.transfer(controller, canExtract));

        TokensWithdrawn(controller, canExtract);
    }

    function months(uint256 m) internal returns (uint256) {
        return m.mul(30 days);
    }

    function getTime() internal returns (uint256) {
        return now;
    }


    //////////
    // Safety Methods
    //////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyController {
        require(_token != address(hna));
        if (_token == 0x0) {
            controller.transfer(this.balance);
            return;
        }

        ERC20 token = ERC20(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(controller, balance);
        ClaimedTokens(_token, controller, balance);
    }

    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
    event TokensWithdrawn(address indexed _holder, uint256 _amount);
}