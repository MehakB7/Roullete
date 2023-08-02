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

    address owner;

    uint expireTime = 1 minutes;

    struct Game {
        address winner;
        mapping(address => bool) hasBet;
        mapping(address => BetType) userToBet;
        uint startTime;
        bool isRunning;
    }
    uint gameId = 0;
    mapping(uint => Game) games;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    modifier onlyOwner() {
        msg.sender == owner;
        _;
    }

    function placeBet(BetType bet) external payable {
        require(msg.value >= Bet, "Insuffiecient Balance");
        require(!games[gameId].hasBet[msg.sender], "user Has already betted");
        games[gameId].userToBet[msg.sender] = bet;
        games[gameId].hasBet[msg.sender] = true;
    }

    function startGame() external onlyOwner {
        Game storage game = games[gameId];
        game.startTime = block.timestamp;
        game.isRunning = true;
    }

    function endGame() external onlyOwner {}
}
