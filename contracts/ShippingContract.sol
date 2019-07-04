pragma solidity 0.4.24;

import "chainlink/contracts/ChainlinkClient.sol";
import "chainlink/contracts/interfaces/AggregatorInterface.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
 * @title ShippingContract is an example contract which requests data from
 * the Chainlink network
 * @dev This contract is designed to work on multiple networks, including
 * local test networks
 */
contract ShippingContract is ChainlinkClient, Ownable {
  using SafeMath for uint256;

  uint256 public constant MIN_AMOUNT = 1000000; // one penny
  bytes32 public constant PRE_TRANSIT = bytes32("pre_transit");
  bytes32 public constant IN_TRANSIT = bytes32("in_transit");
  bytes32 public constant OUT_FOR_DELIVERY = bytes32("out_for_delivery");
  bytes32 public constant DELIVERED = bytes32("delivered");
  bytes32 public constant RETURN_TO_SENDER = bytes32("return_to_sender");
  bytes32 public constant FAILURE = bytes32("failure");
  bytes32 public constant UNKNOWN = bytes32("unknown");

  bytes32 public jobId;
  uint256 public payment;

  AggregatorInterface internal ethReference;

  struct Order {
    address buyer;
    address seller;
    uint256 amount;
    uint256 deadline;
    uint256 balance;
  }

  mapping(bytes32 => Order) private orders;
  mapping(bytes32 => bytes32) private receipts;

  event OrderCreated(
    address indexed buyer,
    address indexed seller,
    uint256 amount,
    uint256 deadline
  );

  event OrderPaid(
    address indexed buyer,
    address indexed seller,
    uint256 amount
  );

  event OrderCancelled(
    address indexed buyer,
    address indexed seller
  );

  /**
   * @notice Deploy the contract with a specified address for the LINK
   * and Oracle contract addresses
   * @dev Sets the storage for the specified addresses
   * @param _link The address of the LINK token contract
   * @param _oracle The address of the oracle contract
   * @param _jobId The Job ID used by the oracle
   * @param _payment The payment for the oracle
   */
  constructor(address _link, address _oracle, address _reference, bytes32 _jobId, uint256 _payment) public {
    if(_link == address(0)) {
      setPublicChainlinkToken();
    } else {
      setChainlinkToken(_link);
    }
    setChainlinkOracle(_oracle);
    jobId = _jobId;
    payment = _payment;
    ethReference = AggregatorInterface(_reference);
  }

  function updateOracleDetails(address _oracle, address _reference, bytes32 _jobId, uint256 _payment) public onlyOwner {
    setChainlinkOracle(_oracle);
    jobId = _jobId;
    payment = _payment;
    ethReference = AggregatorInterface(_reference);
  }

  function createOrder(string _carrier, string _trackingId, address _buyer, uint256 _amount) public {
    bytes32 orderId = keccak256(abi.encodePacked(_carrier, _trackingId));
    require(orders[orderId].amount == 0, "Order already exists");
    require(_amount >= MIN_AMOUNT, "Invalid payment amount");
    Order memory order;
    order.buyer = _buyer;
    order.seller = msg.sender;
    order.amount = _amount;
    order.deadline = now + 30 days;
    emit OrderCreated(order.buyer, order.seller, order.amount, order.deadline);
    orders[keccak256(abi.encodePacked(_carrier, _trackingId))] = order;
  }

  /**
   * @notice Allows the buyer to pay for an order
   * @param _carrier The shipping carrier for the order
   * @param _trackingId The tracking ID for the order
   */
  function payForOrder(string _carrier, string _trackingId) public payable {
    bytes32 orderId = keccak256(abi.encodePacked(_carrier, _trackingId));
    Order memory order = orders[orderId];
    require(order.buyer == msg.sender, "Must be called by buyer");
    require(now <= now - order.deadline, "Order reached deadline");
    require(order.balance == 0, "Order has been paid for");
    require(paymentSupplied(msg.value, orderId, order.amount, order.buyer), "Not enough payment");
    emit OrderPaid(order.buyer, order.seller, order.amount);
  }

  function paymentSupplied(uint256 _paidWei, bytes32 _orderId, uint256 _amountUsd, address _buyer) private returns (bool) {
    uint256 currentRate = uint256(ethReference.currentAnswer());
    uint256 paymentAmountWei = _amountUsd.mul(10**18).div(currentRate);
    if (_paidWei >= paymentAmountWei) {
      uint256 refund = _paidWei.sub(paymentAmountWei);
      orders[_orderId].balance = paymentAmountWei;
      address(_buyer).transfer(refund);
      return true;
	}
    return false;
  }

  function cancelOrder(string _carrier, string _trackingId) public {
    bytes32 orderId = keccak256(abi.encodePacked(_carrier, _trackingId));
    Order memory order = orders[orderId];
    require(order.seller == msg.sender || order.buyer == msg.sender,
      "Must be called by buyer or seller");
    require(now >= now - order.deadline, "Order reached deadline");
    delete orders[orderId];
    address(order.buyer).transfer(order.balance);
    emit OrderCancelled(order.buyer, order.seller);
  }

  function checkShippingStatus(string _carrier, string _trackingId) public {
    bytes32 orderId = keccak256(abi.encodePacked(_carrier, _trackingId));
    Order memory order = orders[orderId];
    require(order.balance > 0, "Order has not been paid for");
    Chainlink.Request memory req = buildChainlinkRequest(jobId, this, this.finalizeOrder.selector);
    req.add("car", _carrier);
    req.add("code", _trackingId);
    receipts[sendChainlinkRequest(req, payment)] = orderId;
  }

  /**
   * @notice The fulfill method from requests created by this contract
   * @dev The recordChainlinkFulfillment protects this function from being called
   * by anyone other than the oracle address that the request was sent to
   * @param _requestId The ID that was generated for the request
   * @param _status The answer provided by the oracle
   */
  function finalizeOrder(bytes32 _requestId, bytes32 _status)
    public
    recordChainlinkFulfillment(_requestId)
  {
    bytes32 orderId = receipts[_requestId];
    Order memory order = orders[orderId];

    // Pay to seller
    if (_status == DELIVERED) {
      delete orders[receipts[_requestId]];
      address(order.seller).transfer(order.balance);
    }

    // Refund buyer
    if (_status == RETURN_TO_SENDER) {
      delete orders[receipts[_requestId]];
      address(order.buyer).transfer(order.balance);
    }

    delete receipts[_requestId];
  }

  /**
   * @notice Allows the owner to withdraw any LINK balance on the contract
   */
  function withdrawLink() public onlyOwner {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
  }

  /**
   * @notice Call this method if no response is received within 5 minutes
   * @param _requestId The ID that was generated for the request to cancel
   * @param _payment The payment specified for the request to cancel
   * @param _callbackFunctionId The bytes4 callback function ID specified for
   * the request to cancel
   * @param _expiration The expiration generated for the request to cancel
   */
  function cancelRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunctionId,
    uint256 _expiration
  )
    public
	onlyOwner
  {
    cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
  }
}