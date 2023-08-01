import { useAccount, useContractWrite, useContractEvent } from "wagmi";
import { contractAddress } from "../contracts/constant";
import abi from "../contracts/roullete.json";
import { ethers } from "ethers";

const Gameplay = () => {
  const address = useAccount();

  const makeBet = useContractWrite({
    address: contractAddress,
    abi: abi,
    functionName: "betOneThird",
    args: ["1"],
    value: ethers.utils.parseEther("0.001"),
    onSuccess(data: any) {
      console.log("trx is send...", data);
    },
    onError(error: any) {
      console.log("error while sending trxs is send...", error);
    },
  });
  console.log("address is", makeBet);

  useContractEvent({
    address: contractAddress,
    abi: abi,
    eventName: "SpinComplete",
    listener(log) {
      console.log("inside this we a have", log);
    },
  });

  return (
    <div>
      <button onClick={() => makeBet.write()}>Make Bet</button>
    </div>
  );
};

export default Gameplay;
