#!/bin/bash

# Call the script using an absolute path
/bin/bash /Users/lucasege/crypto/inter-chain/deterministic-deployment-proxy/scripts/test.sh
# TODO do this for eth too

forge script --rpc-url http://127.0.0.1:8500/4 --sender 0x3e41c6473a51ad613796d5758d01f1c037adf94f --broadcast --unlocked contracts/script/00_DeployEntrypoint.s.sol

forge script --rpc-url http://127.0.0.1:8500/3 --sender 0x3e41c6473a51ad613796d5758d01f1c037adf94f --broadcast --unlocked contracts/script/01_DeploySourceAccount.s.sol 