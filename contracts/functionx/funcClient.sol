// Holds the details of all valid and callable functions
//communicate betweeen the sending contract and consumer

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import {FunctionsConsumer} from "../FunctionsConsumer.sol";
import {PayMaster} from "./paymaster.sol";
import {FuncReg} from "./funcReg.sol";

contract FuncClient {

    event FuncRequest(uint indexed functionId, bytes32 indexed requestId);

    struct Function {
        address admin;
        address caller;
        string topupToken;
        uint functionId;
    }

    struct Request {
        bytes32 requestId;
        uint functionId;
        string[] args;
        bytes returnData;
        bytes err;
        bool status;
        uint time;
    }

    address payable adminAddress;
    uint requestFeeRate; //amount of LINK token to be paid for calling the function
    uint64 subscriptionId;
    uint32 gasLimit;

    FuncReg funcReg;
    PayMaster paymaster;
    FunctionsConsumer functionsConsumer;

    //functionId => requestId => Request
    mapping (uint => mapping (bytes32 => Request)) public requestMap;
    mapping (bytes32 => uint) public requestIdToFunctionId;
    mapping (uint => Request[]) public requestList;

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "Only admin can call this function");
        _;
    }

    constructor(
        address payable funcRegAddress_, 
        address payable paymasterAddress_, 
        address functionsConsumerAddress_,
        address payable adminAddress_, 
        uint requestFeeRate_,
        uint64 subscriptionId_, 
        uint32 gasLimit_
        ) {

        funcReg = FuncReg(funcRegAddress_);
        paymaster = PayMaster(paymasterAddress_);
        functionsConsumer = FunctionsConsumer(functionsConsumerAddress_);
        requestFeeRate = requestFeeRate_;
        subscriptionId = subscriptionId_;
        gasLimit = gasLimit_;
        adminAddress = adminAddress_;
    }

    function updateSubscriptionId(uint64 subscriptionId_) external {
        subscriptionId = subscriptionId_;
    }

    function updateGasLimit(uint32 gasLimit_) external {
        gasLimit = gasLimit_;
    }

    //makeRequest:
    function makeRequest(
        uint functionId, 
        string calldata source, 
        string[] calldata args, 
        bytes calldata secrets
        ) external returns(uint, bytes32)
        {
            
            require(funcReg.getRegisteredFunction(functionId).status == FuncReg.Status.Active, "Function is not active");
            require(funcReg.getRegisteredFunction(functionId).caller == msg.sender, "Caller is not registered");
            address functionAdmin = funcReg.getRegisteredFunction(functionId).admin;
            require(
                paymaster.getAdminBalance(functionAdmin, funcReg.getRegisteredFunction(functionId).topupToken) > 0, "Insufficient balance for functions call"
            );
            (bool success) = paymaster.pay(functionAdmin, funcReg.getRegisteredFunction(functionId).topupToken, requestFeeRate);
            require(success, "Payment failed");
            (bytes32 requestId) = functionsConsumer.executeRequest(source, secrets, args, subscriptionId, gasLimit);
            Request memory newRequest = Request(requestId, functionId, args, "", "", false, 0);
            requestIdToFunctionId[requestId] = functionId;
            requestMap[functionId][requestId] = newRequest;
            requestList[functionId].push(newRequest);
            emit FuncRequest(functionId, requestId);
            return (functionId, requestId);
        }

    function fuffilRequest(bytes32 requestId, bytes calldata returnData, bool status, bytes memory err) external {
        require(msg.sender == address(functionsConsumer), "Only functions consumer can call this function");
        uint functionId = requestIdToFunctionId[requestId];
        requestMap[functionId][requestId].returnData = returnData;
        requestMap[functionId][requestId].err = err;
        requestMap[functionId][requestId].time = block.timestamp;
        requestMap[functionId][requestId].status = status;
    }

    function getLatestRequest(uint functionId) external view returns(Request memory) {
        return requestList[functionId][requestList[functionId].length - 1];
    }

    function getRequests(uint functionId) external view returns(Request[] memory) {
        return requestList[functionId];
    }

    function updateFeeRate(uint requestFeeRate_) external onlyAdmin {
        requestFeeRate = requestFeeRate_;
    }

    function getReturnData(uint functionId, bytes32 requestId) external view returns(bytes memory) {
        return requestMap[functionId][requestId].returnData;
    }

    function withdrawEth() external onlyAdmin{
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable{
       
    }
}