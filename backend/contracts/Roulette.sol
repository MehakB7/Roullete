// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";

contract Roulette is RrpRequesterV0 {
    uint256 public constant MIN_BET = 10000000000000;
    uint256 public spinCount;
    address airnode;
    address immutable deployer;
    address payable sponsorWallet;
    bytes32 endpointId;

    enum BetType {
        Color,
        Number,
        EvenOdd,
        Third,
        Half
    }

    // can do this with only on map ?

    mapping(address => bool) public userBetAColor;
    mapping(address => bool) public userBetANumber;
    mapping(address => bool) public userBetEvenOdd;
    mapping(address => bool) public userBetThird;
    mapping(address => bool) public userBetHalf;
    mapping(address => bool) public userToColor;
    mapping(address => bool) public userToEven;

    //
    mapping(address => uint256) public userToCurrentBet;
    mapping(address => uint256) public userToSpinCount;
    mapping(address => uint256) public userToNumber;
    mapping(address => uint256) public userToThird;
    mapping(address => uint256) public userToHalf;

    mapping(bytes32 => bool) expectingRequestWithIdToBeFulfilled;
    mapping(bytes32 => uint256) public requestIdToSpinCount;
    mapping(bytes32 => uint256) public requestIdToResult;
    mapping(uint256 => bool) blackNumber;
    mapping(uint256 => bool) public blackSpin;
    mapping(uint256 => bool) public spinIsComplete;

    mapping(uint256 => BetType) public spinToBetType;
    mapping(uint256 => address) public spinToUser;
    mapping(uint256 => uint256) public spinResult;
    uint256 public finalNumber;

    //Errors

    error HouseBalanceTooLow();
    error NoBet();
    error ReturnFailed();
    error SpinNotComplete();
    error TransferToDeployerWalletFailed();
    error TransferToSponsorWalletFailed();

    //EVENTS
    event RequestedUint256(bytes32 requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event SpinComplete(
        bytes32 indexed requestId,
        uint256 indexed spinNumber,
        uint256 qrngResult
    );
    event WinningNumber(uint256 indexed spinNumber, uint256 winningNumber);

    constructor(address _airnodeRrp) RrpRequesterV0(_airnodeRrp) {
        deployer = msg.sender;
        blackNumber[2] = true;
        blackNumber[4] = true;
        blackNumber[6] = true;
        blackNumber[8] = true;
        blackNumber[10] = true;
        blackNumber[11] = true;
        blackNumber[13] = true;
        blackNumber[15] = true;
        blackNumber[17] = true;
        blackNumber[20] = true;
        blackNumber[22] = true;
        blackNumber[24] = true;
        blackNumber[26] = true;
        blackNumber[28] = true;
        blackNumber[29] = true;
        blackNumber[31] = true;
        blackNumber[33] = true;
        blackNumber[35] = true;
    }

    function setRequestParameters(
        address _airnode,
        bytes32 _endpointId,
        address payable _sponsorWallet
    ) external {
        require(msg.sender == deployer, "msg.sender is not deployer");
        airnode = _airnode;
        endpointId = _endpointId;
        sponsorWallet = _sponsorWallet;
    }

    function topUpSponserWallet() external payable {
        require(msg.value != 0, "msg.value is 0");
        (bool success, ) = sponsorWallet.call{value: msg.value}("");
        if (!success) {
            revert TransferToSponsorWalletFailed();
        }
    }

    function _spinRouletteWheel(uint256 _spinCount) internal {
        require(!spinIsComplete[_spinCount], "spin already complete");
        require(
            _spinCount == userToSpinCount[msg.sender],
            "!= msg.sender spinCount"
        );
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointId,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        requestIdToSpinCount[requestId] = _spinCount;
        emit RequestedUint256(requestId);
    }

    function fulfillUint256(
        bytes32 requestId,
        bytes calldata data
    ) external onlyAirnodeRrp {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Unexpected Request ID"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 _qrngUint256 = abi.decode(data, (uint256));
        requestIdToResult[requestId] = _qrngUint256;
        _spinComplete(requestId, _qrngUint256);
        finalNumber = (_qrngUint256 % 37);
        emit ReceivedUint256(requestId, _qrngUint256);
    }

    function _spinComplete(bytes32 _requestId, uint256 _qrngUint256) internal {
        uint256 _spin = requestIdToSpinCount[_requestId];
        if (_qrngUint256 == 0) {
            spinResult[_spin] = 37;
        } else {
            spinResult[_spin] = _qrngUint256;
        }
        spinIsComplete[_spin] = true;
        if (spinToBetType[_spin] == BetType.Number) {
            checkIfNumberWon(_spin);
        } else if (spinToBetType[_spin] == BetType.Color) {
            checkIfColorWon(_spin);
        } else if (spinToBetType[_spin] == BetType.EvenOdd) {
            checkIfEvenOddWon(_spin);
        } else if (spinToBetType[_spin] == BetType.Half) {
            checkIfHalfWon(_spin);
        } else if (spinToBetType[_spin] == BetType.Third) {
            checkIfThirdWon(_spin);
        }
        emit SpinComplete(_requestId, _spin, spinResult[_spin]);
    }

    function betNumber(uint256 _numberBet) external payable returns (uint256) {
        require(_numberBet < 37, "_numberBet is > 36");
        require(msg.value >= MIN_BET, "msg.value < MIN_BET");
        if (address(this).balance < msg.value * 35) revert HouseBalanceTooLow();
        userToCurrentBet[msg.sender] = msg.value;
        unchecked {
            ++spinCount;
        }
        userToSpinCount[msg.sender] = spinCount;
        spinToUser[spinCount] = msg.sender;
        userToNumber[msg.sender] = _numberBet;
        userBetANumber[msg.sender] = true;
        spinToBetType[spinCount] = BetType.Number;
        _spinRouletteWheel(spinCount);
        return (userToSpinCount[msg.sender]);
    }

    function checkIfNumberWon(uint256 _spin) internal returns (uint256) {
        address _user = spinToUser[_spin];
        if (userToCurrentBet[_user] == 0) revert NoBet();
        if (!userBetANumber[_user]) revert NoBet();
        if (!spinIsComplete[_spin]) revert SpinNotComplete();
        if (spinResult[_spin] == 37) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user]}("");
            if (!sent) revert ReturnFailed();
        }

        if (userToNumber[_user] == spinResult[_spin] % 37) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 35}("");
            if (!sent) revert HouseBalanceTooLow();
        } else {
            (bool sent, ) = sponsorWallet.call{
                value: userToCurrentBet[_user] / 10
            }("");
            if (!sent) revert TransferToSponsorWalletFailed();
            (bool sent2, ) = deployer.call{value: userToCurrentBet[_user] / 50}(
                ""
            );
            if (!sent2) revert TransferToDeployerWalletFailed();
        }

        userToCurrentBet[_user] = 0;
        userBetANumber[_user] = false;
        emit WinningNumber(_spin, spinResult[_spin] % 37);
        return (spinResult[_spin] % 37);
    }

    function betOneThird(
        uint256 _oneThirdBet
    ) external payable returns (uint256) {
        require(
            _oneThirdBet == 1 || _oneThirdBet == 2 || _oneThirdBet == 3,
            "_oneThirdBet not 1 or 2 or 3"
        );
        require(msg.value >= MIN_BET, "msg.value < MIN_BET");
        if (address(this).balance < msg.value * 3) revert HouseBalanceTooLow();
        userToCurrentBet[msg.sender] = msg.value;
        unchecked {
            ++spinCount;
        }
        spinToUser[spinCount] = msg.sender;
        userToSpinCount[msg.sender] = spinCount;
        userToThird[msg.sender] = _oneThirdBet;
        userBetThird[msg.sender] = true;
        spinToBetType[spinCount] = BetType.Third;
        _spinRouletteWheel(spinCount);
        return (userToSpinCount[msg.sender]);
    }

    function checkIfThirdWon(uint256 _spin) internal returns (uint256) {
        address _user = spinToUser[_spin];
        if (userToCurrentBet[_user] == 0) revert NoBet();
        if (!userBetThird[_user]) revert NoBet();
        if (!spinIsComplete[_spin]) revert SpinNotComplete();
        uint256 _result = spinResult[_spin] % 37;
        uint256 _thirdResult;
        if (_result > 0 && _result < 13) {
            _thirdResult = 1;
        } else if (_result > 12 && _result < 25) {
            _thirdResult = 2;
        } else if (_result > 24) {
            _thirdResult = 3;
        }
        if (spinResult[_spin] == 37) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user]}("");
            if (!sent) revert ReturnFailed();
        }
        if (userToThird[_user] == 1 && _thirdResult == 1) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 3}("");
            if (!sent) revert HouseBalanceTooLow();
        } else if (userToThird[_user] == 2 && _thirdResult == 2) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 3}("");
            if (!sent) revert HouseBalanceTooLow();
        } else if (userToThird[_user] == 3 && _thirdResult == 3) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 3}("");
            if (!sent) revert HouseBalanceTooLow();
        } else {
            (bool sent, ) = sponsorWallet.call{
                value: userToCurrentBet[_user] / 10
            }("");
            if (!sent) revert TransferToSponsorWalletFailed();
            (bool sent2, ) = deployer.call{value: userToCurrentBet[_user] / 50}(
                ""
            );
            if (!sent2) revert TransferToDeployerWalletFailed();
        }
        userToCurrentBet[_user] = 0;
        userBetThird[_user] = false;
        emit WinningNumber(_spin, spinResult[_spin] % 37);
        return (spinResult[_spin] % 37);
    }

    function betHalf(uint256 _halfBet) external payable returns (uint256) {
        require(_halfBet == 1 || _halfBet == 2, "_halfBet not 1 or 2");
        require(msg.value >= MIN_BET, "msg.value < MIN_BET");
        if (address(this).balance < msg.value * 2) revert HouseBalanceTooLow();
        userToCurrentBet[msg.sender] = msg.value;
        unchecked {
            ++spinCount;
        }
        spinToUser[spinCount] = msg.sender;
        userToSpinCount[msg.sender] = spinCount;
        userToHalf[msg.sender] = _halfBet;
        userBetHalf[msg.sender] = true;
        spinToBetType[spinCount] = BetType.Half;
        _spinRouletteWheel(spinCount);
        return (userToSpinCount[msg.sender]);
    }

    function checkIfHalfWon(uint256 _spin) internal returns (uint256) {
        address _user = spinToUser[_spin];
        if (userToCurrentBet[_user] == 0) revert NoBet();
        if (!userBetHalf[_user]) revert NoBet();
        if (!spinIsComplete[_spin]) revert SpinNotComplete();
        uint256 _result = spinResult[_spin] % 37;
        uint256 _halfResult;
        if (_result > 0 && _result < 19) {
            _halfResult = 1;
        } else if (_result > 18) {
            _halfResult = 2;
        }
        if (spinResult[_spin] == 37) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user]}("");
            if (!sent) revert ReturnFailed();
        } else {}
        if (userToHalf[_user] == 1 && _halfResult == 1) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 2}("");
            if (!sent) revert HouseBalanceTooLow();
        } else if (userToHalf[_user] == 2 && _halfResult == 2) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 2}("");
            if (!sent) revert HouseBalanceTooLow();
        } else {
            (bool sent, ) = sponsorWallet.call{
                value: userToCurrentBet[_user] / 10
            }("");
            if (!sent) revert TransferToSponsorWalletFailed();
            (bool sent2, ) = deployer.call{value: userToCurrentBet[_user] / 50}(
                ""
            );
            if (!sent2) revert TransferToDeployerWalletFailed();
        }
        userToCurrentBet[_user] = 0;
        userBetHalf[_user] = false;
        emit WinningNumber(_spin, spinResult[_spin] % 37);
        return (spinResult[_spin] % 37);
    }

    function betEvenOdd(bool _isEven) external payable returns (uint256) {
        require(msg.value >= MIN_BET, "msg.value < MIN_BET");
        if (address(this).balance < msg.value * 2) revert HouseBalanceTooLow();
        unchecked {
            ++spinCount;
        }
        spinToUser[spinCount] = msg.sender;
        userToCurrentBet[msg.sender] = msg.value;
        userToSpinCount[msg.sender] = spinCount;
        userBetEvenOdd[msg.sender] = true;
        if (_isEven) {
            userToEven[msg.sender] = true;
        }
        spinToBetType[spinCount] = BetType.EvenOdd;
        _spinRouletteWheel(spinCount);
        return (userToSpinCount[msg.sender]);
    }

    function checkIfEvenOddWon(uint256 _spin) internal returns (uint256) {
        address _user = spinToUser[_spin];
        if (userToCurrentBet[_user] == 0) revert NoBet();
        if (!userBetEvenOdd[_user]) revert NoBet();
        if (!spinIsComplete[_spin]) revert SpinNotComplete();
        uint256 _result = spinResult[_spin] % 37;
        if (spinResult[_spin] == 37) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user]}("");
            if (!sent) revert ReturnFailed();
        } else {}
        if (_result == 0) {
            (bool sent, ) = sponsorWallet.call{
                value: userToCurrentBet[_user] / 10
            }("");
            if (!sent) revert TransferToSponsorWalletFailed();
        } else if (userToEven[_user] && (_result % 2 == 0)) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 2}("");
            if (!sent) revert HouseBalanceTooLow();
        } else if (!userToEven[_user] && _result % 2 != 0) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 2}("");
            if (!sent) revert HouseBalanceTooLow();
        } else {
            (bool sent, ) = sponsorWallet.call{
                value: userToCurrentBet[_user] / 10
            }("");
            if (!sent) revert TransferToSponsorWalletFailed();
            (bool sent2, ) = deployer.call{value: userToCurrentBet[_user] / 50}(
                ""
            );
            if (!sent2) revert TransferToDeployerWalletFailed();
        }
        userBetEvenOdd[_user] = false;
        userToCurrentBet[_user] = 0;
        emit WinningNumber(_spin, spinResult[_spin] % 37);
        return (spinResult[_spin] % 37);
    }

    function betColor(bool _isBlack) external payable returns (uint256) {
        require(msg.value >= MIN_BET, "msg.value < MIN_BET");
        if (address(this).balance < msg.value * 2) revert HouseBalanceTooLow();
        unchecked {
            ++spinCount;
        }
        spinToUser[spinCount] = msg.sender;
        userToCurrentBet[msg.sender] = msg.value;
        userToSpinCount[msg.sender] = spinCount;
        userBetAColor[msg.sender] = true;
        if (_isBlack) {
            userToColor[msg.sender] = true;
        } else {}
        spinToBetType[spinCount] = BetType.Color;
        _spinRouletteWheel(spinCount);
        return (userToSpinCount[msg.sender]);
    }

    function checkIfColorWon(uint256 _spin) internal returns (uint256) {
        address _user = spinToUser[_spin];
        if (userToCurrentBet[_user] == 0) revert NoBet();
        if (!userBetAColor[_user]) revert NoBet();
        if (!spinIsComplete[_spin]) revert SpinNotComplete();
        uint256 _result = spinResult[_spin] % 37;
        if (spinResult[_spin] == 37) {
            (bool sent, ) = _user.call{value: userToCurrentBet[_user]}("");
            if (!sent) revert ReturnFailed();
        } else if (_result == 0) {
            (bool sent, ) = sponsorWallet.call{
                value: userToCurrentBet[_user] / 10
            }("");
            if (!sent) revert TransferToSponsorWalletFailed();
            (bool sent2, ) = deployer.call{value: userToCurrentBet[_user] / 50}(
                ""
            );
            if (!sent2) revert TransferToDeployerWalletFailed();
        } else {
            if (blackNumber[_result]) {
                blackSpin[_spin] = true;
            } else {}
            if (userToColor[_user] && blackSpin[_spin]) {
                (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 2}(
                    ""
                );
                if (!sent) revert HouseBalanceTooLow();
            } else if (
                !userToColor[_user] && !blackSpin[_spin] && _result != 0
            ) {
                (bool sent, ) = _user.call{value: userToCurrentBet[_user] * 2}(
                    ""
                );
                if (!sent) revert HouseBalanceTooLow();
            } else {
                (bool sent, ) = sponsorWallet.call{
                    value: userToCurrentBet[_user] / 10
                }("");
                if (!sent) revert TransferToSponsorWalletFailed();
                (bool sent2, ) = deployer.call{
                    value: userToCurrentBet[_user] / 50
                }("");
                if (!sent2) revert TransferToDeployerWalletFailed();
            }
        }
        userBetAColor[_user] = false;
        userToCurrentBet[_user] = 0;
        emit WinningNumber(_spin, spinResult[_spin] % 37);
        return (spinResult[_spin] % 37);
    }

    receive() external payable {}
}
