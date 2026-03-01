contract=$(jq -r '.transactions[0].contractAddress' broadcast/Solid.s.sol/$chain/run-latest.json)
args=$(cast abi-encode "constructor(uint256)" $(jq -r '.transactions[].arguments[0]' broadcast/Solid.s.sol/$chain/run-latest.json))
forge verify-contract $contract Solid --chain $chain --verifier etherscan --show-standard-json-input > script/Solid.json
