// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

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
    mapping(uint256 => Lobby) private lobbies;

    enum PlayerDecision {
        HIT,
        STAND,
        DOUBLE_DOWN
    }
    /*
    *  Lobby struct, contains all the information about the lobby, including the players, their cards, their bets, and the deck.
    */
    struct Lobby{
        //Not visible
        uint256 seed;
        uint256 lobbyid;
        uint8[] dealerCards;
        address[] players;
        uint16 maxPlayers;
        bool isReady; 
        mapping(address => uint256) cardTotals;
        mapping(address => bool) isComplete;
        mapping(address => bool) hasWon;
        mapping(address => uint256) playerBets;
        mapping(address => uint8[]) playerCards;
    }

    modifier onlyLobbyOwner(uint256 _lobbyid) {
        require(msg.sender == lobbies[_lobbyid].players[0], "You are not the lobby owner");
        _;
    }


    constructor() ConfirmedOwner(msg.sender) VRFV2WrapperConsumerBase(link_address, wrapper_address) {}

    //Entry point
    function createGame(uint16 _maxPlayers) public payable returns(bool) {
        require(msg.value > 0, "You must bet at least 1 wei");


        //Make a request to the backend card generation, we use the ID returned by it to identify the lobby.
        uint256 request = generate();
        Lobby storage curr = lobbies[request];
        //Lobby setup
        curr.lobbyid = request;
        curr.players.push(msg.sender);
        curr.playerBets[msg.sender] = msg.value;
        curr.maxPlayers = _maxPlayers;
        curr.isComplete[msg.sender] = false;
        curr.isReady = false;
        emit GameCreated(request, msg.sender, msg.value);
        return true;
    }


    function joinGame(uint256 _lobbyid) public payable returns(bool){

        Lobby storage curr = lobbies[_lobbyid];
        require(curr.lobbyid == _lobbyid, "Lobby does not exist");
        require(curr.playerBets[msg.sender] == 0, "You are already in this lobby");
        require(msg.value > 0, "You must bet at least 1 wei");
        require(curr.players.length < curr.maxPlayers, "Lobby is full");
        require(curr.isReady == true, "Lobby is ready");

        //Adds user to the lobby with their bet.
        curr.players.push(msg.sender);
        curr.playerBets[msg.sender] = msg.value;
        curr.isComplete[msg.sender] = false;
        emit JoinedLobby(_lobbyid, msg.sender, msg.value);
        return true;
    }

    uint8[52] private deck = [11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10];
    
    //Should be random enough
    function getCard(uint256 _lobbyid) internal view returns(uint8){
        Lobby storage curr = lobbies[_lobbyid];
        uint8 card = deck[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, curr.seed))) % 52];
        return card;
    }

    
    function startGame(uint256 _lobbyid) public onlyLobbyOwner(_lobbyid)  {
        
        Lobby storage curr = lobbies[_lobbyid];
        require(curr.isReady == true, "Lobby is not ready");
        require(curr.players.length >= 1, "Not enough players");

        //Deal cards
        curr.dealerCards.push(getCard(_lobbyid));

        for(uint8 i = 0; i < curr.players.length; i++){
            uint8 card1 = getCard(_lobbyid);
            uint8 card2 = getCard(_lobbyid);

            
            curr.playerCards[curr.players[i]].push(card1);
            curr.playerCards[curr.players[i]].push(card2);
            curr.cardTotals[curr.players[i]] += card1+card2;

            emit CardsDealt(curr.playerCards[curr.players[i]], curr.players[i]);
        }

        //Deal cards to the dealer
        
        curr.dealerCards.push(getCard(_lobbyid));

        emit DealerCardUp(curr.dealerCards[1], address(this));
    }

    function playCurrentHand(PlayerDecision _choice, uint256 _lobbyid) public payable {
        Lobby storage curr = lobbies[_lobbyid];
        address player = msg.sender;
        //Check if game has already ended
        require(curr.isComplete[player] == false, "You have already completed your hand");
        require(curr.lobbyid == _lobbyid, "Lobby does not exist");
        
        if(msg.value == (curr.playerBets[msg.sender] * 2) && _choice == PlayerDecision.DOUBLE_DOWN){
            curr.playerBets[player] += msg.value;
            
            uint8 card = getCard(_lobbyid);
            curr.playerCards[player].push(card);
            curr.cardTotals[player] += card;
            emit NewCardPlayer(card, player);
            curr.isComplete[player] = true;
        }


        if(_choice == PlayerDecision.HIT){
            //This is where I think there can be issues with not having enough cards.
            uint8 card = getCard(_lobbyid);
            curr.playerCards[player].push(card);
            emit NewCardPlayer(card, player);
            curr.cardTotals[player] += card;

            if(curr.cardTotals[player] > 21){
                curr.isComplete[player] = true;
                curr.hasWon[player] = false;
            }
        } else {
            curr.isComplete[player] = true;
        }

        //Check if all players have completed their hands
        bool allComplete = true;
        for(uint8 i = 0; i < curr.players.length; i++){
            if(curr.isComplete[curr.players[i]] == false){
                allComplete = false;
            }
        }

        if(allComplete == true){
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
