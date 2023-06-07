//Keeps track of balances 
//Exchange rate between selected token and link for function call 


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PayMaster {

    event NewFunctionAdded(address indexed admin, uint indexed id);
    event TopUp(address indexed admin, bool indexed success);
    event AdminWithdrawn(bool indexed success, string indexed token);

    struct Topup {
        address tokenAddress;
        string ticker;
    }

    struct Function {
        address admin;
        uint functionId;
        Topup topupToken;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "Only admin can call this function");
        _;
    }

    address public linkEthAggrAddress;
    address public linkUsdAggrAddress;
    address public functionRegAddress;
    address public funcClientAddress;
    address public adminAddress;
    AggregatorV3Interface internal linkEth;
    AggregatorV3Interface internal linkUsd;

    mapping (address => mapping(string => uint)) public balances;
    mapping (string => Topup) public topups;
    mapping (uint => Function) public regFunctionsMap;
    
    constructor(address linkEthAggrAddress_, address linkUsdAggrAddress_, address admin) {
        linkEthAggrAddress = linkEthAggrAddress_;
        linkUsdAggrAddress = linkUsdAggrAddress_;
        linkEth = AggregatorV3Interface(linkEthAggrAddress);
        linkUsd = AggregatorV3Interface(linkEthAggrAddress);
        adminAddress = admin;
    }

    function addTopUpToken (address tokenAddress, string calldata ticker) external onlyAdmin returns(bool) {
        require(topups[ticker].tokenAddress == address(0), "Token already added");
        require(tokenAddress != address(0), "Invalid token address");
        Topup memory newTopup = Topup(tokenAddress, ticker);
        topups[ticker] = newTopup;
        return true;
    }

    function getTopUpToken (string calldata ticker) external view returns(Topup memory){
        return topups[ticker];
    }

    function addFunction (address admin, string calldata topupToken, uint functionId) external returns(bool){
      require(topups[topupToken].tokenAddress != address(0), "Token not added");
      require(admin != address(0), "Invalid admin address");
        require(functionId != 0, "Invalid function id");
        Function memory newFunction = Function(admin, functionId, topups[topupToken]);
        regFunctionsMap[functionId] = newFunction;
        return true;
    }

    function getFunction (uint functionId) external view returns(Function memory){
        return regFunctionsMap[functionId];
    }

    function topUp (address admin, string calldata topupToken, uint amount) external returns(bool){
       require(amount != 0, "topup balance cannot be 0");
        require(topups[topupToken].tokenAddress != address(0), "Token not added");
        //check that paymaster is approved to spend the token
        require(IERC20(topups[topupToken].tokenAddress).allowance(msg.sender, address(this)) >= amount, "paymaster Not approved");
        require(IERC20(topups[topupToken].tokenAddress).balanceOf(msg.sender) >= amount, "Insufficient balance");
        (bool success) = IERC20(topups[topupToken].tokenAddress).transferFrom(admin, address(this), amount);
        require(success, "Transfer failed");
        balances[admin][topupToken] = amount;
        emit TopUp(admin, true);
        return true;
    }

    function getAdminBalance (address admin, string calldata topupToken) external view returns(uint){
        return balances[admin][topupToken];
    }

    function adminWithdraw (string calldata ticker) external {
        require(balances[msg.sender][ticker] != 0, "Insufficient balance");
        if (keccak256(abi.encodePacked(ticker)) == keccak256(abi.encodePacked("ETH"))) {
            balances[msg.sender][ticker] = 0;
            payable(msg.sender).transfer(balances[msg.sender][ticker]);
        } else {
            balances[msg.sender][ticker] = 0;  
           IERC20(topups[ticker].tokenAddress).transfer(msg.sender, balances[msg.sender][ticker]);
        }
        emit AdminWithdrawn(true, ticker);
    }

    function getConversion (string calldata topupToken, uint amount) public view returns(uint){
        (,int ethVal,,,) = linkEth.latestRoundData();
        (,int usdVal,,,) = linkUsd.latestRoundData();

        if (keccak256(abi.encodePacked(topupToken)) == keccak256(abi.encodePacked("ETH"))) {
            return amount * uint256(ethVal);
        } else {
            return amount * uint256(usdVal);
        }

    }

    function setup(address functionRegAddr, address funcClient)external onlyAdmin{
        functionRegAddress = functionRegAddr;
        funcClientAddress = funcClient;
    }

    function pay (address admin, string calldata topupToken, uint amount) external returns(bool){
        require (msg.sender == funcClientAddress, "Only funcClient can call this function");
        require(amount != 0, "amount cannot be 0");
        uint conversion = getConversion(topupToken, amount);
        require(balances[admin][topupToken] >= conversion, "admin Insufficient balance");
        balances[admin][topupToken] -= conversion;
        return true;
    }

    function withdrawEth() external onlyAdmin{
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawToken(address tokenAddress) external onlyAdmin{
        IERC20(tokenAddress).transfer(msg.sender, IERC20(tokenAddress).balanceOf(address(this)));
    }

    receive() external payable{
        balances[msg.sender]["ETH"] = msg.value;
    }
    
}