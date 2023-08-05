// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

contract MinRoullete {
    // Minimilastc random rollete using blocktimestamp1
    uint public constant Bet = 0.001 ether;
    enum BetType {
        Red, //
        Green,
        Black
    }
    address owner;
    uint expireTime = 1 minutes;
    struct Game {
        uint result;
        mapping(address => bool) hasBet;
        mapping(address => BetType) userToBet;
        address[] participants;
        uint startTime;
        uint endTime;
        bool isRunning;
    }
    uint gameId = 0;
    mapping(uint => Game) public games;

    event gameStart();
    event gameEnded(uint result);

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
        require(games[gameId].isRunning, "Game is already running");
        require(
            block.timestamp <= games[gameId].endTime,
            " Betting time has expired"
        );
        games[gameId].userToBet[msg.sender] = bet;
        games[gameId].hasBet[msg.sender] = true;
        games[gameId].participants.push(msg.sender);
    }

    function startGame() external onlyOwner returns (uint) {
        Game storage game = games[gameId];
        game.startTime = block.timestamp;
        game.isRunning = true;
        game.endTime = block.timestamp + expireTime;
        emit gameStart();
        return gameId;
    }

    function endGame() external onlyOwner {
        Game storage game = games[gameId];
        game.isRunning = false;
        // calculate the random number;
        game.result =
            uint256(keccak256(abi.encodePacked((block.timestamp)))) %
            2;
        gameId++;

        for (uint i = 0; i < game.participants.length; i++) {
            address _address = address(game.participants[i]);
            if (game.userToBet[_address] == BetType(game.result)) {
                (bool success, ) = payable(_address).call{value: Bet}("");
                require(success);
            }
        }

        emit gameEnded(game.result);
    }

    function totalPlayer(uint _gameId) external view returns (uint) {
        Game storage game = games[_gameId];
        return game.participants.length;
    }
}
