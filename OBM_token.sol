pragma solidity ^0.4.18;

import "./oraclizeAPI_0.4.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./ERC20.sol";
import "./burnable.sol";
import "./RefundVault.sol";

contract OBMCrowdsale is burnableToken, usingOraclize {
    
  using SafeMath for uint256;


  string public name = "Orbeum";
  string public symbol = "OBM";
  uint8 public decimals = 18;
  uint256 public totalSupply = 5500000000 * 10 ** uint(decimals);
  uint256 public publicAllocation = 4000000000 * 10 ** uint(decimals);
  uint256 public promotionBonus = 800000000 * 10 ** uint(decimals);
  uint256 public WeeklyBonus = 400000000 * 10 ** uint(decimals);
  uint256 public FounderAllocation = 100000000 *10 ** uint(decimals);
  uint256 public ProjectReserve = 200000000 * 10 ** uint(decimals);
  
  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime; 
  uint256 public endTime; 

  //set the softcap in USD
  uint256 public softcap = 500000; 
  
  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per wei
  uint public price;

  // amount of raised money in wei
  uint256 public weiRaised;
  
  // amount of raised money in usd
  uint256 public fundrised;
  
  bool public priceupdated = false;
  bool public isFinalized = false;
  bool public softcapReached = false;

  
  RefundVault public vault;
  

  /**
  * event for token purchase logging
  * @param purchaser who paid for the tokens
  * @param beneficiary who got the tokens
  * @param value weis paid for purchase
  * @param amount amount of tokens purchased
  */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event newOraclizeQuery(string description);
  event newEtherPrice(string price);
  event Burn(address indexed burner, uint256 value);
  event Finalized();



  function OBMCrowdsale () public {
    

    wallet = msg.sender;
    owner = msg.sender;
    balances[owner] = totalSupply;
    vault = new RefundVault(wallet);

  }

  function __callback(bytes32 myid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        newEtherPrice(result);
        price = parseInt(result, 2); // let's save it as $ cents
        // do something with the USD ethereum price
        if(!priceupdated){
            priceupdated = true;
        }

        StartUpdatingPrice(3600 * 12);
  }
    

    function StartUpdatingPrice(uint delay) payable public {
        newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        oraclize_query(delay, "URL", "json(https://api.etherscan.io/api?module=stats&action=ethprice&apikey=YourApiKeyToken).result.ethusd");
    }
  

  /**
 * Internal transfer, only can be called by this contract
 */
    function _transfer(address _from, address _to, uint256 _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balances[_from] >= _value);
        // Check for overflows
        require(balances[_to] + _value > balances[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balances[_from].add(balances[_to]);
        // Subtract from the sender
        balances[_from] = balances[_from].sub(_value);
        // Add the same to the recipient
        balances[_to] = balances[_to].add(_value);
        Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balances[_from] + balances[_to] == previousBalances);
    }


  // fallback function can be used to buy tokens
  function () external payable {
    if(msg.sender != owner) buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(validPurchase());

    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = getTokenAmount(weiAmount);
    
    require(tokens <= publicAllocation);
    
    publicAllocation = publicAllocation.sub(tokens);
    
    _transfer(owner, beneficiary, tokens);
    sendweeklyBonus(beneficiary, tokens);
    
    weiRaised = weiRaised.add(msg.value);
    fundrised = weiRaised.mul(price).div(10 ** 20);
    
    if (fundrised >= softcap && !softcapReached) {
      softcapReached = true;
      vault.close();
    }
    
    if (softcapReached) {
        wallet.transfer(msg.value);
    } else {
        forwardFunds();
    }
    

  }


  /**
  * @dev Must be called after crowdsale ends, to do some extra finalization
  * work. Calls the contract's finalization function.
  */
  function finalize() onlyOwner public {
    require(!isFinalized);
    require(hasEnded());
    
    if (!softcapReached) {
      vault.enableRefunds();
    }
    balances[owner] = balances[owner].sub(publicAllocation);
    totalSupply = totalSupply.sub(publicAllocation);
    publicAllocation = 0;
    Finalized();
    isFinalized = true;
  }
  
  // if crowdsale is unsuccessful, investors can claim refunds here
  function claimRefund() public {

    require(isFinalized);
    require(!softcapReached);

    vault.refund(msg.sender);
  }
  

 
  function setICOstarttime(uint _starttime) public onlyOwner {
      startTime = _starttime;
  }
  
  function setICOendtime(uint _endtime) public onlyOwner {
      endTime = _endtime;
  }
  // @return true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }

  // Override this method to have a way to add business logic to your crowdsale when buying
  function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {
    return weiAmount.mul(price);
  }


  function forwardFunds() internal {
    vault.deposit.value(msg.value)(msg.sender);
  }
  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase && priceupdated;
  }
  
  function sendweeklyBonus(address to, uint256 tokens) internal {
      
      uint256 value;
      
      if( now > startTime && now <= startTime + 2 weeks){
          value = tokens.div(10);
      } else if( now >startTime + 2 weeks && now <= startTime + 3 weeks) {
          value = tokens.div(8).div(100);
      } else if( now >startTime + 3 weeks && now <= startTime + 4 weeks) {
          value = tokens.mul(7).div(100);
      } else if( now >startTime + 4 weeks && now <= startTime + 5 weeks) {
          value = tokens.mul(5).div(100);
      } else if( now >startTime + 5 weeks && now <= startTime + 6 weeks) {
          value = tokens.mul(3).div(100);
      } else if( now >startTime + 6 weeks && now <= startTime + 7 weeks) {
          value = tokens.mul(2).div(100);
      } else {
          value = 0;
      }
      require(to != 0x0 && WeeklyBonus >= value);
      balances[owner] = balances[owner].sub(value);
      balances[to] = balances[to].add(value);
      WeeklyBonus = WeeklyBonus.sub(value);
      Transfer(owner, to, value);     
  }
  function sendreserves (address to, uint256 _value) public onlyOwner {
      uint256 value = _value * 10 ** uint(decimals);
      require(to != 0x0 && ProjectReserve >= value);
      balances[owner] = balances[owner].sub(value);
      balances[to] = balances[to].add(value);
      ProjectReserve = ProjectReserve.sub(value);
      Transfer(owner, to, value);
  }
  
  function sendfounderallocations(address to, uint256 _value) public onlyOwner {
      uint256 value = _value * 10 ** uint(decimals);
      require(to != 0x0 && FounderAllocation >= value);
      balances[owner] = balances[owner].sub(value);
      balances[to] = balances[to].add(value);
      FounderAllocation = FounderAllocation.sub(value);
      Transfer(owner, to, value);
  }

  function sendPromotionbonus(address to, uint256 _value) public onlyOwner {
      uint256 value = _value * 10 ** uint(decimals);
      require(to != 0x0 && promotionBonus >= value);
      balances[owner] = balances[owner].sub(value);
      balances[to] = balances[to].add(value);
      promotionBonus = promotionBonus.sub(value);
      Transfer(owner, to, value);
  }  
  function sendextraweeklybonus(address to, uint256 _value) public onlyOwner {
        uint256 value = _value * 10 ** uint(decimals);
        require(isFinalized);
        require(to != 0x0 && WeeklyBonus >= value);
        balances[owner] = balances[owner].sub(value);
        balances[to] = balances[to].add(value);
        WeeklyBonus = WeeklyBonus.sub(value);
        Transfer(owner, to, value);
    }
}
