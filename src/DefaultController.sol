
pragma solidity ^0.4.23;

import "ds-stop/stop.sol";
import "./TokenController.sol";
import "./Controlled.sol";

contract DefaultController is DSStop, TokenController {
    mapping (address => bool) public isBlack;

    constructor(address[] _blacks) public {
        for (uint i=0; i<_blacks.length; i++) {
            isBlack[_blacks[i]] = true;
        }
    }

    function changeController(address _token, address _newController) public auth {
        Controlled(_token).changeController(_newController);
    }

    function proxyPayment(address _owner) payable public returns (bool)
    {
        return false;
    }

    function onTransfer(address _from, address _to, uint _amount) public returns (bool)
    {
        if (!stopped && isBlack[_from])
        {
            return false;
        }
        
        return true;
    }

    function onApprove(address _owner, address _spender, uint _amount) public returns (bool)
    {
        return true;
    }

    function addBlack(address black) public auth
    {
        isBlack[black] = true;
    }
    
    function removeBlack(address black) public auth
    {
        isBlack[black] = false;
    }
}