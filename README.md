# flipblob-contracts

<p align="center">
  <img src="spin.gif" alt="flip animation"/>
</p>
<h3 align="center">🪙 Coin Flip Experience on Starknet 🪙</h3>
<h4 align="center">Take a chance and flip your way to double your stakes!</h4>

<p align="center">
  Experience the thrill of the flip on StarkNet. Will fortune smile upon you? <br>
</p>

<p align="center">
  Ready to test your luck? Visit <a href="https://flipblob.com/">flipblob.com</a> to start flipping!
</p>

<h5 align="center">Coming Sooner Than You Expect...</h5>

### USEFUL COMMANDS
```bash
# test 
snforge test

# build
scarb build

# declare and deploy
sncast --account ffbbcc --network testnet --url https://starknet-goerli.infura.io/v3/5bfa78a2165d4d169dc9c519ab5a42a6 declare --contract-name Flip --max-fee 969082993868615
sncast --account ffbbcc --network testnet --url https://starknet-goerli.infura.io/v3/5bfa78a2165d4d169dc9c519ab5a42a6 deploy --class-hash 0x23b5c3797f2f03ec96d9897392a962fe66892e8c8c44f99f46242e4ddb515c9 --max-fee 969082993868615
