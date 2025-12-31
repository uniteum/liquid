contract=$(jq -r '.transactions[0].contractAddress' broadcast/Uniteum.s.sol/$chain/dry-run/run-latest.json)
forge verify-contract $contract Uniteum --chain $chain --verifier etherscan --show-standard-json-input > io/$chain/Uniteum.json
