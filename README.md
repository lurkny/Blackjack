# Welcome to Blackjack!

This project is still under development, but I am welcoming all contributions! This contract will most likely live on the Sepolia testnet, because I don't have to time or money to actually run this contract on mainnet.

# Installation/Setup

1. Clone this repo into its own folder
2. Run npm install 

## Deployment
No script has been written to deploy this contract. If you want to make your own before I do, know that this contract **requires** both **ETH** an **LINK** to work.
>Get ETH and LINK here -> https://faucets.chain.link/


## How the contract works

1. User calls createGame() on the Blackjack contract.
2. Blackjack then calls generate() on the DeckGeneration contract.
3. generate() returns a uint256 ID that we use to identify different lobbies.
4. While Chainlink is fetching the random number to seed our shuffle, other users may join my calling joinGame() with a lobby id. 
5. Once the deck has been created, our game can begin, and the creator of the lobby calls startGame(), and everyone is dealt their cards. The creator of the game can now call playCurrentHand(), with their choice of hit and stand + the lobby ID, and the rest of the playing order is determined by join time (FIFO).
6. Once the last person in lobby has played, the contract then calls an **internal** function settleGame() which determines if each hand won or lost, and pays each player out accordingly.
>Note: There are some missing features from the game, like insurance and doubling down. Ill add it when I feel that the rest of the code is in a good place.

