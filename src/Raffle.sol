// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author Abel Sisay
 * @notice This contract is for creating a sample raffle
 * @dev Implements chainlinks VRF2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__SendMoreToRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotneeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN, //0
        CALCUATING //1

    }

    /**
     * State Variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyhash;
    uint256 private immutable i_subscriptionID;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    address payable private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    //** Events */
    // Makes migration easier
    // makes forntend indexing easier
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionID,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        // @dev te duration of every Raffle in seconds
        i_interval = interval;
        i_entranceFee = entranceFee;
        i_keyhash = gasLane;
        i_subscriptionID = subscriptionID;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee,"Not Enough ETH sent!!")
        //  require(msg.value >= i_entranceFee,SendMoreToRaffle())
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink nodes will call to see if the
     * lottery is ready to have a winner picked.
     * THe following should be true in order for upkeepNeeded to be true!
     * 1.The time interval has passed between raffle run s
     * 2 The lottery is open
     * 3. The contract has ETH
     * 4.Implicitly,your subscriptions has LINK
     * @param -null /ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     *
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /*perfromData*/ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function perfromUpkeep(bytes calldata /*performData */ ) external {
        // Check if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotneeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCUATING;

        // Create the RandomWordsRequest struct using the correct type
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyhash,
            subId: i_subscriptionID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    // CEI :Checks ,Effects ,Interactions
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override {
        // Checks
        // Effects (Internal State Changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions (External State Changes);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }
}
