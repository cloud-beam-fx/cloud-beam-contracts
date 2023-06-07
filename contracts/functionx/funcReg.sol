//Register function
//creates id for registered function
//holds record of registered function

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {PayMaster} from "./paymaster.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FuncReg {

    event NewFunctionRegistered(address indexed admin, uint indexed id);
    event FunctionRegCancel(address indexed admin, uint indexed id);
    event FunctionStateChange(uint indexed id, uint indexed status);

    enum Status {Active, Paused, Deprecated}

    struct Function {
        address admin;
        address caller;
        string topupToken;
        uint functionId;
        Status status;
    }
    address payable paymasterAddress;

    uint[] public functionIds;
    mapping(uint => Function) public functionMap;
    mapping (address => uint[] ) public adminFunctions;
    address adminAddress;

    modifier onlyPaymaster() {
        require(msg.sender == paymasterAddress, "Only paymaster can call this function");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "Only admin can call this function");
        _;
    }
        

    constructor(address _paymasterAddress, address admin) {
        paymasterAddress = payable(_paymasterAddress);
        adminAddress = admin;
    }

    function registerFunction (address admin, address caller, string calldata topupToken ) external returns(uint){
        PayMaster paymaster = PayMaster(paymasterAddress);
        require(paymaster.getTopUpToken(topupToken).tokenAddress != address(0), "Token not added for ticker");
        uint id = functionIds.length + 1;
        Function memory newFunction = Function(admin, caller, topupToken, id, Status.Active);
        functionMap[id] = newFunction;
        functionIds.push(id);
        adminFunctions[admin].push(id);
        paymaster.addFunction(admin, topupToken, id);
        emit NewFunctionRegistered(msg.sender, id);
        return id;
    }

    function toogleFunctionState (uint id) external {
        require(msg.sender == this.getRegisteredFunction(id).admin);
        require(functionMap[id].status != Status.Deprecated, "Function deprecated");
        if (functionMap[id].status == Status.Active){
            functionMap[id].status = Status.Paused;
        } else {
            functionMap[id].status = Status.Active;
        }

        emit FunctionStateChange(id, uint(functionMap[id].status));
    }
    
    function getRegisteredFunction (uint id) external view returns(Function memory){
        //returns function struct
        return functionMap[id];
    }

    function getRegisteredFunctions () external view returns(Function[] memory){
        //returns array of function structs
        Function[] memory functions = new Function[](functionIds.length);
        for (uint i = 0; i < functionIds.length; i++) {
            functions[i] = functionMap[functionIds[i]];
        }
        return functions;
    }

    function getAdminFunctions (address admin) external view returns(Function[] memory){
        //returns array of function structs
        Function[] memory functions = new Function[](adminFunctions[admin].length);
        for (uint i = 0; i < adminFunctions[admin].length; i++) {
            functions[i] = functionMap[adminFunctions[admin][i]];
        }
        return functions;
    }
    
    function cancelRegFunctions (uint id) external{
        require(msg.sender == this.getRegisteredFunction(id).admin);
        functionMap[id].status = Status.Deprecated;
        emit FunctionRegCancel(msg.sender, id);
    }

    //function for admin to withdraw ETH from contract
    function withdrawEth() external onlyAdmin{
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawToken(address tokenAddress) external onlyAdmin{
        IERC20(tokenAddress).transfer(msg.sender, IERC20(tokenAddress).balanceOf(address(this)));
    }


    receive() external payable{ 
    }
}