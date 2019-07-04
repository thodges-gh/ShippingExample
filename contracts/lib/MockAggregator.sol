pragma solidity 0.4.24;

import "chainlink/contracts/interfaces/AggregatorInterface.sol";

contract MockAggregator is AggregatorInterface {
  int256 internal _currentAnswer = 29297642655;
  uint256 internal _updatedHeight = 10000000;

  function currentAnswer() external view returns (int256) {
    return _currentAnswer;
  }

  function updatedHeight() external view returns (uint256) {
    return _updatedHeight;
  }
}