// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


import "./Blackjack.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

contract DeckGeneration is VRFV2WrapperConsumerBase, ConfirmedOwner {
    BlackJack blackjack;

    //Hardcoded sepolia addresses
    address constant linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    uint32 constant callbackGas = 1_000_000;
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 3;

    event DeskRequest(uint256 requestId);
    event Status(uint256 requestId, bool isDone);
    mapping(uint256 => DeckStatus) public requestStatus;

        struct DeckStatus {
        uint256 fees;
        uint256 lobbyID;
        bool fulfilled;
    }

    uint8[52] deck = [11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10,11,2,3,4,5,6,7,8,9,10,10,10,10];

 

    constructor() ConfirmedOwner(msg.sender) VRFV2WrapperConsumerBase(linkAddress, wrapperAddress){}


    //Required callback function, recieves the randomness that chainlink generated and shuffles the deck, then calls the blackjack contract to deal the cards.
     function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(requestStatus[requestId].fees  > 0, "Request does not exist");
        uint8[52] memory unshuffled;

        uint cardIndex;
        for(uint8 i=0; i < 52; i++) {
            cardIndex = randomWords[0] % (52 - i);
            deck[i] = unshuffled[cardIndex];
             unshuffled[cardIndex] = unshuffled[52 - i - 1];
      }

        requestStatus[requestId].fulfilled = true;
        blackjack.recieveCards(deck, requestStatus[requestId].lobbyID);
        emit Status(requestId, true);
   }
        
    
    //Entry Point to the contract, requests a random number and returns the request ID
    function generate() external  returns(uint256){

        uint256 request = requestRandomness(
            callbackGas,
            requestConfirmations,
            numWords
        );

        requestStatus[request] = DeckStatus({
            fees: VRF_V2_WRAPPER.calculateRequestPrice(callbackGas),
            lobbyID: request,
            fulfilled: false
        });
        emit DeskRequest(request);
        return request;
    }

    
 
    //Debug
    function getStatus(uint256 requestId) public view returns(DeckStatus memory) {
        return requestStatus[requestId];
    }
    
    //selfdestruct
    function clear() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
         require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
        

    }



}
