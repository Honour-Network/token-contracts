pragma solidity ^0.4.17;

// After contract creation (deployment) of  HNAtoken, if financing is required, the contract is deployed.
// The fifth parameter of the constructor is the address of the HNA contract, which can be used to manipulate the token transfer.
// You can set fundraising deadlines, target funds, exchange ether prices, beneficiaries, lockout time.
// After the fund-raising is over, if the target is reached, the money is given to the beneficiary, if not, it is returned to the investor.
// If you have multiple fundraising, you can deploy this smart contract multiple times

import "ds-auth/auth.sol";
import "./lib/SafeMath.sol";
import "./HNA.sol";

contract HNAContribution is DSAuth {
    using SafeMath for uint256;

    uint256 constant public exchangeRate = 5000;   // will be set before the token sale.
    uint256 constant public maxGasPrice = 100000000000;  // 100GWei

    mapping(address => bool) public whiteList;

    HNA public  hna;            // The HNA token itself

    address public destEthFoundation;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public totalNormalTokenTransfered;
    uint256 public totalNormalEtherCollected;

    bool public paused;

    modifier initialized() {
        require(address(hna) != 0x0);
        _;
    }

    modifier contributionOpen() {
        require(time() >= startTime &&
            time() <= endTime &&
            address(hna) != 0x0);
        _;
    }

    modifier notPaused() {
        require(!paused);
        _;
    }

    function HNAContribution() {
    }


    /// @notice This method should be called by the owner before the contribution
    ///  period starts This initializes most of the parameters
    /// @param _hna Address of the HNA token contract
    ///  the contribution finalizes.
    /// @param _startTime Time when the contribution period starts
    /// @param _endTime Time when the contribution period ends
    /// @param _destEthFoundation Destination address where the contribution ether is sent
    function initialize(
        address _hna,
        uint _startTime,
        uint _endTime,
        address _destEthFoundation
    ) public auth {
        // Initialize only once
        require(address(hna) == 0x0);

        hna = HNA(_hna);
        require(hna.decimals() == 18);  // Same amount of decimals as ETH

        startTime = _startTime;
        endTime = _endTime;

        assert(startTime < endTime);

        require(_destEthFoundation != 0x0);
        destEthFoundation = _destEthFoundation;

    }

    function saveWhiteList(address[] _addrList, bool alive) public auth {
        for (uint i = 0; i < _addrList.length; i++) {
            whiteList[_addrList[i]] = alive;
        }
        // EventSaveSwap(true);
    }

    function savePaused(bool _paused) public auth {
        paused = _paused;
    }

  /// @notice If anybody sends Ether directly to this contract, consider he is
  ///  getting HNAs.
    function () public payable {
        proxyPayment(msg.sender);

    }

  /// @notice This method will generally be called by the HNA token contract to
  ///  acquire HNAs. Or directly from third parties that want to acquire HNAs in
  ///  behalf of a token holder.
  /// @param _th HNA holder where the HNAs will be minted.
    function proxyPayment(address _th) public payable initialized contributionOpen notPaused returns (bool) {
        require(_th != 0x0);
        require(whiteList[_th]);

        buyNormal(_th);

        return true;
    }

    function buyNormal(address _th) internal {
        require(tx.gasprice <= maxGasPrice);

        //   // Antispam mechanism
        //   // TODO: Is this checking useful?
        address caller;
        if (msg.sender == address(hna)) {
            caller = _th;
        } else {
            caller = msg.sender;
        }

        //   // Do not allow contracts to game the system
        require(!isContract(caller));

        doBuy(_th, msg.value);
    }

    function doBuy(address _th, uint256 _toFund) public {
        require(tx.gasprice <= maxGasPrice);

        assert(msg.value >= _toFund);  // Not needed, but double check.

        uint256 endOfFirstWeek = startTime.add(1 weeks);
        uint256 endOfSecondWeek = startTime.add(2 weeks);
        uint256 finalExchangeRate = exchangeRate;
        if (now < endOfFirstWeek) {
            // 10% Bonus in first week
            finalExchangeRate = exchangeRate.mul(110).div(100);
        } else if (now < endOfSecondWeek) {
            // 5% Bonus in second week
            finalExchangeRate = exchangeRate.mul(105).div(100);
        }

        if (_toFund > 0) {
            uint256 tokensGenerating = _toFund.mul(finalExchangeRate);

            if (tokensGenerating > hna.balanceOf(this)) {
                tokensGenerating = hna.balanceOf(this);
                _toFund = hna.balanceOf(this).div(finalExchangeRate);
            }

            require(hna.transfer(_th, tokensGenerating));

            destEthFoundation.transfer(_toFund);

            totalNormalTokenTransfered = totalNormalTokenTransfered.add(tokensGenerating);

            totalNormalEtherCollected = totalNormalEtherCollected.add(_toFund);

            NewSale(_th, _toFund, tokensGenerating);
        }

        uint256 toReturn = msg.value.sub(_toFund);
        if (toReturn > 0) {
            _th.transfer(toReturn);
        }
    }


  /// @dev Internal function to determine if an address is a contract
  /// @param _addr The address being queried
  /// @return True if `_addr` is a contract
    function isContract(address _addr) constant internal returns (bool) {
        if (_addr == 0) {
            return false;
        }
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function time() constant returns (uint) {
        return block.timestamp;
    }


  //////////
  // Safety Methods
  //////////

  /// @notice This method can be used by the controller to extract mistakenly
  ///  sent tokens to this contract.
  /// @param _token The address of the token contract that you want to recover
  ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public auth {
        if (_token == 0x0) {
            owner.transfer(this.balance);
            return;
        }

        ERC20 token = ERC20(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(owner, balance);
        ClaimedTokens(_token, owner, balance);
    }

    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
    event NewSale(address indexed _th, uint256 _amount, uint256 _tokens);
}