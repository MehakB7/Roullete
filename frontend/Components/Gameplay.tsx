import { useAccount, useContractWrite, useContractEvent } from "wagmi";
import { contractAddress } from "../contracts/constant";
import abi from "../contracts/roullete.json";

const Gameplay = () => {
  const address = useAccount();

  const makeBet = useContractWrite({
    address: contractAddress,
    abi: abi,
    functionName: "betOneThird",
    args: ["1"],
    onSuccess(data: any) {
      console.log("trx is send...", data);
    },
    onError(error: any) {
      console.log("trx is send...", error);
    },
  });

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
