// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

contract MinRoullete {
    // Minimilastc random rollete using blocktimestamp1
    uint public constant Bet = 0.001 ether;
    enum BetType {
        Red,
        Green,
        Black
    }

    mapping(address => BetType) userToBet;

    receive() external payable {}

    function placeBet(BetType bet) external payable {
        require(msg.value >= Bet, "Insuffiecient Balance");
        userToBet[msg.sender] = bet;
        // get random number and send it back to user

        // send it back to user
    }
}
