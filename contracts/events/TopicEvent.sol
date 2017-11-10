pragma solidity ^0.4.18;

import "../libs/Ownable.sol";
import "../libs/SafeMath.sol";

contract TopicEvent is Ownable {
    using SafeMath for uint256;

    struct Result {
        bytes32 name;
        uint256 balance;
        mapping (address => uint256) betBalances;
    }

    bool public finalResultSet;
    uint8 private finalResultIndex;
    address public oracle;
    bytes32 public name;
    uint256 public bettingEndBlock;
    Result[10] results;

    // Events
    event TopicCreated(bytes32 _name);
    event BetAccepted(address _better, uint _resultIndex, uint256 _betAmount, uint256 _betBalance);
    event WinningsWithdrawn(uint256 _amountWithdrawn);
    event FinalResultSet(uint _finalResultIndex);

    // Modifiers
    modifier onlyResultSetter() {
        require(msg.sender == oracle);
        _;
    }

    modifier validResultIndex(uint _resultIndex) {
        require(_resultIndex >= 0);
        require(_resultIndex <= results.length - 1);
        _;
    }

    modifier validBet() {
        require(block.number < bettingEndBlock);
        require(msg.value > 0);
        _;
    }

    modifier hasEnded() {
        require(block.number >= bettingEndBlock);
        _;
    }

    modifier finalResultNotSet() {
        require(!finalResultSet);
        _;
    }

    modifier finalResultIsSet() {
        require(finalResultSet);
        _;
    }

    /// @notice Creates new TopicEvent contract.
    /// @param _owner The address of the owner.
    /// @param _oracle The address of the individual Oracle that will decide the result.
    /// @param _name The question or statement of the TopicEvent.
    /// @param _resultNames The possible results of the TopicEvent.
    /// @param _bettingEndBlock The block when TopicEvent voting will end.
    function TopicEvent(
        address _owner,
        address _oracle,
        bytes32 _name, 
        bytes32[10] _resultNames,
        uint256 _bettingEndBlock)
        Ownable(_owner)
        public
        validAddress(_oracle)
    {
        require(_name.length > 0);
        require(_resultNames.length > 1);
        require(_bettingEndBlock > block.number);

        owner = _owner;
        oracle = _oracle;
        name = _name;

        for (uint i = 0; i < _resultNames.length; i++) {
            if (_resultNames[i].length > 0) {
                results[i] = Result({
                    name: _resultNames[i],
                    balance: 0
                });
            } else {
                break;
            }
        }

        bettingEndBlock = _bettingEndBlock;

        TopicCreated(name);
    }

    function bet(uint _resultIndex) public validBet payable {
        Result storage updatedResult = results[_resultIndex];
        updatedResult.balance = updatedResult.balance.add(msg.value);
        updatedResult.betBalances[msg.sender] = updatedResult.betBalances[msg.sender].add(msg.value);
        results[_resultIndex] = updatedResult;

        BetAccepted(msg.sender, _resultIndex, msg.value, results[_resultIndex].betBalances[msg.sender]);
    }

    function revealResult(uint8 _resultIndex)
        public
        onlyResultSetter
        hasEnded
        validResultIndex(_resultIndex)
        finalResultNotSet
    {
        finalResultIndex = _resultIndex;
        finalResultSet = true;
        FinalResultSet(finalResultIndex);
    }

    function withdrawWinnings() public hasEnded finalResultIsSet {
        uint256 totalTopicBalance = getTotalTopicBalance();
        require(totalTopicBalance > 0);

        Result storage finalResult = results[finalResultIndex];
        uint256 betBalance = finalResult.betBalances[msg.sender];
        require(betBalance > 0);

        // Clear out balance in case withdrawBet() is called again before the prior transfer is complete
        finalResult.betBalances[msg.sender] = 0;

        uint256 withdrawAmount = totalTopicBalance.mul(betBalance).div(finalResult.balance);
        require(withdrawAmount > 0);

        msg.sender.transfer(withdrawAmount);

        WinningsWithdrawn(withdrawAmount);
    }

    function destroy() external onlyOwner {
        selfdestruct(owner);
    }

    function getResultName(uint _resultIndex) 
        public 
        validResultIndex(_resultIndex) 
        constant 
        returns (bytes32) 
    {
        return results[_resultIndex].name;
    }

    function getResultBalance(uint _resultIndex) 
        public 
        validResultIndex(_resultIndex) 
        constant 
        returns (uint256) 
    {
        return results[_resultIndex].balance;
    }

    function getBetBalance(uint _resultIndex) 
        public 
        validResultIndex(_resultIndex) 
        constant 
        returns (uint256) 
    {
        return results[_resultIndex].betBalances[msg.sender];
    }

    function getTotalTopicBalance() public constant returns (uint256) {
        uint256 totalTopicBalance = 0;
        for (uint i = 0; i < results.length; i++) {
            totalTopicBalance = results[i].balance.add(totalTopicBalance);
        }
        return totalTopicBalance;
    }

    function getFinalResultIndex() 
        public 
        finalResultIsSet 
        constant 
        returns (uint8) 
    {
        return finalResultIndex;
    }

    function getFinalResultName() 
        public 
        finalResultIsSet 
        constant 
        returns (bytes32) 
    {
        return results[finalResultIndex].name;
    }
}
