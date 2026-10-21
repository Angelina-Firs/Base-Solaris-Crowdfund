const hre = require("hardhat");
async function main() {
  const CrowdfundEngine = await hre.ethers.getContractFactory("SolarisCrowdfund");
  const solaris = await CrowdfundEngine.deploy();
  await solaris.deployed();
  console.log("-> Solaris Crowdfund Engine live at:", solaris.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
