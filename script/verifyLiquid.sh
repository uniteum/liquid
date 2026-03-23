contract=$(jq -r '.transactions[0].contractAddress' broadcast/Liquid.s.sol/$chain/run-latest.json)
args=$(cast abi-encode "constructor(address)" $(jq -r '.transactions[].arguments[0]' broadcast/Liquid.s.sol/$chain/run-latest.json))
forge verify-contract $contract Liquid --chain $chain --verifier etherscan --show-standard-json-input > script/Liquid.json
