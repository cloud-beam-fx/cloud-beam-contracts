const hre = require("hardhat");
const {config} = require("hardhat");
const  {existsSync, mkdirSync, writeFileSync} = require("fs");
const {networks} = require("../networks");


const writeAddress = (addresses) => {
    const addressPath = "./Addresses/depolyed.json";
    if(!existsSync("./Addresses")){
        mkdirSync("./Addresses");
    }
    writeFileSync(addressPath, JSON.stringify(addresses, null, 2), (err) => {
        if(err) console.log(err);
    });
};

console.log("Admin address: ", config.networks.hardhat.accounts);

const main = async () => {
    let linkEthAggregator = "0x0715A7794a1dc8e42615F059dD6e406A6594651A"; //change address according to network
    let linkUsdAggregator = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";
    let adminAddress = "0x23142E15b262D787344671C4B079A0510C682527";
    let reqRate = 0.35;
    let subscriptionId = 1;
    let gasLimit = 1e5;
    //format requestFeeRate to uint
    const requestFeeRate = hre.ethers.utils.parseUnits(reqRate.toString(), 10);
    const usdtAddress = "0x0715A7794a1dc8e42615F059dD6e406A6594651A";
    const usdcAddress = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";
    const daiAddress = "0x23142E15b262D787344671C4B079A0510C682527";

    //Import contracts
    const FunctionConsumer = await hre.ethers.getContractFactory("FunctionsConsumer");
    const FuncClient = await hre.ethers.getContractFactory("FuncClient");
    const PayMaster = await hre.ethers.getContractFactory("PayMaster");
    const FuncReg = await hre.ethers.getContractFactory("FuncReg");

    //Deploy contracts
    //get deployer address

    const functionConsumer = await FunctionConsumer.deploy(networks.polygonMumbai.functionsOracleProxy);
    await functionConsumer.deployed();
    const payMaster = await PayMaster.deploy(linkEthAggregator, linkUsdAggregator, adminAddress);
    await payMaster.deployed();
    const funcReg = await FuncReg.deploy(payMaster.address, adminAddress);
    await funcReg.deployed();
    const funcClient = await FuncClient.deploy(funcReg.address, payMaster.address, functionConsumer.address, adminAddress, requestFeeRate,subscriptionId, gasLimit );
    await funcClient.deployed();

    //Initilize contracts
    const paySetup = await payMaster.setup(funcReg.address, funcClient.address);
    await paySetup.wait();
    const addTopupToken = await payMaster.addTopUpToken(usdcAddress, "USDC");
    await addTopupToken.wait();
    const consumerSetup = await functionConsumer.setup(funcClient.address, adminAddress);
    await consumerSetup.wait();

    let deployed = {
      FunctionConsumer: functionConsumer.address,
      PayMaster: payMaster.address,
      FuncReg: funcReg.address,
      FuncClient: funcClient.address
  }

  writeAddress(deployed);

    console.table({
        "FunctionConsumer": functionConsumer.address,
        "PayMaster": payMaster.address,
        "FuncReg": funcReg.address,
        "FuncClient": funcClient.address
    })
};

main().then().catch((err) => {console.log(err); process.exit(1);});