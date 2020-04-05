import { internalTask } from "@nomiclabs/buidler/config";
import { utils } from "ethers";

export default internalTask(
  "gc-mintexecclaim:defaultpayload:ActionERC20TransferFrom",
  `Returns a hardcoded actionPayload of ActionERC20TransferFrom`
)
  .addFlag("log")
  .setAction(async ({ log }) => {
    try {
      const isLuis = false;

      /*
        address user;
        address userProxy;
        address sendToken;
        address destination;
        uint256 sendAmount;
      */

      if (!isLuis) {
        // ActionERC20TransferFrom Params
        const { hilmar: user, luis: destination } = await run("bre-config", {
          addressbookcategory: "EOA",
        });
        const { hilmar: userProxy } = await run("bre-config", {
          addressbookcategory: "userProxy",
        });
        const { DAI: sendToken } = await run("bre-config", {
          addressbookcategory: "erc20",
        });
        const sendAmount = utils.parseUnits("1", 18);

        // Params as sorted array of inputs for abi.encoding
        const inputs = [
          {
            user,
            userProxy,
            sendToken,
            destination,
            sendAmount,
          },
        ];
        // Encoding
        const payloadWithSelector = await run("abi-encode-withselector", {
          contractname: "ActionERC20TransferFrom",
          functionname: "action",
          inputs,
          log,
        });
        return payloadWithSelector;
      } else {
        // ActionERC20TransferFrom Params
        const { devluis: user, luis: destination } = await run("bre-config", {
          addressbookcategory: "EOA",
        });
        const { luis: userProxy } = await run("bre-config", {
          addressbookcategory: "userProxy",
        });
        const { KNC: sendToken } = await run("bre-config", {
          addressbookcategory: "erc20",
        });
        const sendAmount = utils.parseUnits("10", 18);

        // Params as sorted array of inputs for abi.encoding
        // action(_user, _userProxy, _src, _srcAmt, _beneficiary)
        const inputs = [
          [user, userProxy],
          [sendToken, destination],
          sendAmount,
        ];
        // Encoding
        const payloadWithSelector = await run("abi-encode-withselector", {
          contractname: "ActionERC20TransferFrom",
          functionname: "action",
          inputs,
          log,
        });

        return payloadWithSelector;
      }
    } catch (err) {
      console.error(err);
      process.exit(1);
    }
  });
