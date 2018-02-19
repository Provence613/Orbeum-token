pragma solidity ^0.4.18;

import "./ERC20.sol";


/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract burnableToken is ERC20 {

  event Burn(address indexed burner, uint256 value);

  function burn(uint256 _value) public returns (bool success) {
      
    address burner = msg.sender;
    require(_value <= balances[burner]);

    balances[burner] = balances[burner].sub(_value);
    totalSupply = totalSupply.sub(_value);
    Burn(burner, _value);
    return true;
  }

}
