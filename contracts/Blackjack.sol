// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18.0;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

/*
*   IMPORTANT NOTES:
*   - The majority of the logic in this contract relies on the lobbyID, which is returned in createGame() and is used to identify the lobby.
*   - Most requirements about msg.value are just placeholders for values that will be modified later.
*
*   
*   A small summary of a game:
*   1. Player 1 creates a game with a bet of 1 wei, and a max of 2 players.
*   2. This contract calls the DeckGeneration contract to generate a deck of cards.
*   3. The DeckGeneration contract calls the Chainlink VRF to generate a random number.
*   4. The Chainlink VRF returns the random number to the DeckGeneration contract.
*   5. The DeckGeneration contract shuffles the deck and calls the recieveCards() function in this contract.
*   6. recieveCards() stores the deck in the lobby struct and sets the lobby to ready.
*   7. Player 2 joins the lobby with a bet of 1 wei.
*   8. Player 2 is dealt 2 cards, and the dealer is dealt 2 cards.
*   9. Player 1 is dealt 2 cards.
*   10. Player 1 is prompted to make a decision, either hit or stand.
*/

contract BlackJack is VRFV2WrapperConsumerBase, ConfirmedOwner {

    //Hardcoded sepolia addresses
    address constant private link_address = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant private wrapper_address = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    uint32 constant private callback_gas = 1_000_000;
    uint32 constant  private num_words = 1;
    uint16 constant private request_confirmations = 3;

    event DeckRequest(uint256 requestId);
    event Status(uint256 requestId, bool isDone);
    mapping(uint256 => DeckStatus) public requestStatus;


    struct DeckStatus {
        uint256 fees;
        uint256 lobbyID;
        bool fulfilled;
    }


    function generate() internal returns(uint256){

        uint256 request = requestRandomness(
            callback_gas,
            request_confirmations,
            num_words
        );

        requestStatus[request] = DeckStatus({
            fees: VRF_V2_WRAPPER.calculateRequestPrice(callback_gas),
            lobbyID: request,
            fulfilled: false
        });
        emit DeckRequest(request);
        return request;
    }

     function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(requestStatus[requestId].fees  > 0, "Request does not exist");
        
        Lobby storage curr = lobbies[requestId];
        DeckStatus storage status = requestStatus[requestId];

        status.fulfilled = true;
        curr.lobbyid = requestId;
        curr.seed = randomWords[0];
        curr.isReady = true;
        emit GameReady(requestId);
   }
    

    //Will add more events later
    event GameCreated(uint256 lobbyID, address player, uint256 bet);
    event GameReady(uint256 lobbyID);
    event JoinedLobby(uint256 lobbyID, address player, uint256 bet);
    event HandResult(uint256 lobbyID, address player, bool win);
    event CardsDealt(uint8[] cards, address player);
    event DealerCardUp(uint8 card, address dealer);
    event NewCardPlayer(uint8 card, address player);

    //LobbyID => Lobby
    mapping(uint256 => Lobby) public lobbies;

    enum PlayerDecision {
        HIT,
        STAND,
        DOUBLE_DOWN
    }
    /*
    *  Lobby struct, contains all the information about the lobby, including the players, their cards, their bets, and the deck.
    */
    struct Lobby{
        uint256 seed;
        uint256 leftToHit;
        uint256 lobbyid;
        uint256 lastDecisionTime;
        uint8[] dealerCards;
        address[] players;
        uint16 maxPlayers;
        uint32 entryCutoff;
        bool isReady; 
        bool hasSettled;
        mapping(address => uint256) cardTotals;
        mapping(address => uint256) playerBets;
        mapping(address => uint8[]) playerCards;
        mapping(address => bool) hasStood;
        mapping(address => bool) playerTurn;
    }

    modifier onlyLobbyOwner(uint256 _lobbyid) {
        require(msg.sender == lobbies[_lobbyid].players[0], "You are not the lobby owner");
        _;
    }


    constructor() ConfirmedOwner(msg.sender) VRFV2WrapperConsumerBase(link_address, wrapper_address) {}


    function createGame(uint16 _maxPlayers, uint32 _entryCutoffTime) public payable returns(bool) {
        require(msg.value > 0, "You must bet at least 1 wei");
        require(_entryCutoffTime > block.timestamp, "Game must start in the future");


        //Make a request to the backend card generation, we use the ID returned by it to identify the lobby.
        uint256 request = generate();
        Lobby storage curr = lobbies[request];
        //Lobby setup
        curr.lobbyid = request;
        curr.entryCutoff = _entryCutoffTime;
        curr.players.push(msg.sender);
        curr.playerBets[msg.sender] = msg.value;
        curr.maxPlayers = _maxPlayers;
        curr.leftToHit = curr.players.length;
        emit GameCreated(request, msg.sender, msg.value);
        return true;
    }


    function joinGame(uint256 _lobbyid) public payable returns(bool){

        Lobby storage curr = lobbies[_lobbyid];
        require(curr.lobbyid == _lobbyid, "Lobby does not exist");
        require(curr.entryCutoff <= block.timestamp, "Entering game after entry cutoff.");
        require(curr.playerBets[msg.sender] == 0, "You are already in this lobby");
        require(msg.value > 0, "You must bet at least 1 wei");
        require(curr.players.length < curr.maxPlayers, "Lobby is full");
        require(curr.isReady == true, "Lobby is ready");

        //Adds user to the lobby with their bet.
        curr.players.push(msg.sender);
        curr.playerBets[msg.sender] = msg.value;
        emit JoinedLobby(_lobbyid, msg.sender, msg.value);
        return true;
    }

    uint8[52] deck = [11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10];
    

    //Should be random enough
    function getCard(uint256 _lobbyid) internal view returns(uint8){
        uint256 seed = lobbies[_lobbyid].seed;
        uint8 card = deck[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % 52];
        seed += uint256(keccak256(abi.encodePacked(lobbies[_lobbyid].players[(seed - 10) % lobbies[_lobbyid].players.length])));
        return card;
    }
    
    function startGame(uint256 _lobbyid) public onlyLobbyOwner(_lobbyid)  {
        
        Lobby storage curr = lobbies[_lobbyid];
        require(curr.entryCutoff > block.timestamp, "Starting game before entry cutoff.");
        require(curr.isReady == true, "Lobby is not ready");
        require(curr.players.length > 1, "Not enough players");

        //Deal cards to the players
        for(uint256 i = 0; i < curr.players.length; i++){
            curr.playerCards[curr.players[i]].push(getCard(_lobbyid));
            curr.playerCards[curr.players[i]].push(getCard(_lobbyid));
            curr.cardTotals[curr.players[i]] = curr.playerCards[curr.players[i]][0] + curr.playerCards[curr.players[i]][1];
            emit CardsDealt(curr.playerCards[curr.players[i]], curr.players[i]);
        }

        //Deal cards to the dealer
        curr.dealerCards.push(getCard(_lobbyid));
        curr.dealerCards.push(getCard(_lobbyid));

        //Set the player turn to the first player
        curr.playerTurn[curr.players[0]] = true;
        lobbies[_lobbyid].lastDecisionTime = block.timestamp;

        emit DealerCardUp(curr.dealerCards[1], address(this));
    }

    function playCurrentHand(PlayerDecision _choice, uint256 _lobbyid) public payable {
        Lobby storage curr = lobbies[_lobbyid];
        //Check if game has already ended
        require(!curr.hasSettled, "Game has already settled");
        //Check if the player is in the lobby and can play/players play time has ended

        require((curr.playerTurn[msg.sender] == true) || ((curr.lastDecisionTime + 90 < block.timestamp) && (curr.playerBets[msg.sender] > 0)), "Player has already played / Can't play yet");
        Lobby storage curr = lobbies[_lobbyid];

        address player;
        for(uint8 i = 0; i < curr.players.length; i++){
            if(curr.playerTurn[curr.players[i]] == true){
                player = curr.players[i];
                curr.playerTurn[curr.players[i+1]] = true;
                break;
            }
        }
        //Check if user has already stood, don't let them play if so
        require(!curr.hasStood[player], "Player has already stood their hand");
        curr.playerTurn[player] = false;

        if (player != msg.sender) _choice = PlayerDecision.STAND;

        if(_choice == PlayerDecision.HIT){
            //This is where I think there can be issues with not having enough cards.
            uint8 card = getCard(_lobbyid);
            curr.playerCards[player].push(card);
            emit NewCardPlayer(card, player);
            curr.cardTotals[player] += card;

            //Check if the player has busted (kinda unnecessary)
            if(curr.cardTotals[player] >= 21){
                curr.leftToHit--;
                curr.hasStood[player] = true;
            }
        } else if(_choice == PlayerDecision.STAND) {
            curr.leftToHit--;
            curr.hasStood[player] = true;
        } else {
            require(msg.value == curr.playerBets[player]);
            curr.playerBets[player] += msg.value;
            uint8 card = getCard(_lobbyid);
            curr.playerCards[player].push(card);
            emit NewCardPlayer(card, player);
            curr.cardTotals[player] += card;
            curr.leftToHit--;
            curr.hasStood[player] = true;
        }

        if ((player == curr.players[curr.players.length - 1]) && (curr.leftToHit == 0)) {
            settleGame(_lobbyid);
        }
    }


    function settleGame(uint256 _lobbyid) internal {
        //get the dealer total
        Lobby storage curr  = lobbies[_lobbyid];
        uint256 dealerTotal = curr.dealerCards[0] + curr.dealerCards[1];
        
        while (dealerTotal <= 16){
            uint8 card = getCard(_lobbyid);
            curr.dealerCards.push(card);
            emit DealerCardUp(card, address(this));
            dealerTotal += card;
        }
         
         curr.hasSettled = true;
         for(uint8 i = 0; i < curr.players.length ; i++){
            if((curr.cardTotals[curr.players[i]] > dealerTotal && curr.cardTotals[curr.players[i]] < 22) || (dealerTotal > 21  && curr.cardTotals[curr.players[i]] < 22)){
                //Win
                (bool sent,) = payable(curr.players[i]).call{value: curr.playerBets[curr.players[i]] * 2}("");
                require(sent, "Failed to send Ether");
                emit HandResult(_lobbyid, curr.players[i], true);
            }else if((curr.cardTotals[curr.players[i]] > 21) || (curr.cardTotals[curr.players[i]] < dealerTotal && dealerTotal < 22) ){
                //Lose
                emit HandResult(_lobbyid, curr.players[i], false);
            }else {
                //Push
                (bool sent,) = payable(curr.players[i]).call{value: curr.playerBets[curr.players[i]]}("");
                require(sent, "Failed to send Ether");
                emit HandResult(_lobbyid, curr.players[i], true);
            }
         }
    }
}
