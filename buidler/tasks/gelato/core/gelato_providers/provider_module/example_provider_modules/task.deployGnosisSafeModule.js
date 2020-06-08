import { task } from "@nomiclabs/buidler/config";
import { defaultNetwork } from "../../../../../../../buidler.config";
import { utils, constants } from "ethers";

export default task(
  "gc-deploy-gnosis-safe-module",
  `Deploys the ProviderModuleGnosisSafe on [--network] (default: ${defaultNetwork})`
)
  .addOptionalParam(
    "mastercopy",
    "address of gnosis safe mastercopy to whitelist"
  )
  .addOptionalParam(
    "extcodehash",
    "bytes of gnosis safe extcodehash to whitelist"
  )
  .addOptionalParam("multisend", "address of multisend contract to whitelist")
  .addFlag("events", "Logs parsed Event Logs to stdout")
  .addFlag("log", "Logs return values to stdout")
  .setAction(async (taskArgs) => {
    try {
      // TaskArgs Sanitzation
      // Gelato Provider is the 3rd signer account
      const gelatoProvider = getProvider();

      if (!gelatoProvider)
        throw new Error("\n gelatoProvider not instantiated \n");

      const gelatoCore = await run("instantiateContract", {
        contractname: "GelatoCore",
        signer: gelatoProvider,
        write: true,
      });

      // 1. Get Mastercopy
      if (!taskArgs.mastercopy) {
        taskArgs.mastercopy = await run("bre-config", {
          addressbookcategory: "gnosisSafe",
          addressbookentry: "mastercopy",
        });
      }

      // get multisend contract
      if (!taskArgs.multisend)
        taskArgs.multisend = await run("bre-config", {
          addressbookcategory: "gnosisSafe",
          addressbookentry: "multiSend",
        });

      if (!taskArgs.extcodehash) {
        // 1. Get extcodehash of Gnosis Safe
        const safeAddress = await run("gc-determineCpkProxyAddress");
        let providerToRead = ethers.provider;
        const extcode = await providerToRead.getCode(safeAddress);
        taskArgs.extcodehash = utils.solidityKeccak256(["bytes"], [extcode]);
      }

      const providerModuleGnosisSafeProxy = await run("deploy", {
        contractname: "ProviderModuleGnosisSafeProxy",
        constructorargs: [
          [taskArgs.extcodehash],
          [taskArgs.mastercopy],
          gelatoCore.address,
          taskArgs.multisend,
        ],
        events: taskArgs.events,
        log: taskArgs.log,
        signer: gelatoProvider,
      });

      if (taskArgs.log)
        console.log(
          `Provider Module Gnosis Safe Proxy Address: ${providerModuleGnosisSafeProxy.address}`
        );
      return providerModuleGnosisSafeProxy;
    } catch (error) {
      console.error(error, "\n");
      process.exit(1);
    }
  });