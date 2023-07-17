#!/bin/bash

# Call the script using an absolute path
# /bin/bash /Users/lucasege/crypto/inter-chain/deterministic-deployment-proxy/scripts/test.sh
# TODO do this for eth too

# Deploy Entrypoint
forge script --rpc-url http://127.0.0.1:8500/4 --sender 0x3e41c6473a51ad613796d5758d01f1c037adf94f --broadcast --unlocked contracts/script/00_DeployEntrypoint.s.sol

# Deploy SourceAccount 0xF7Aa721C14fAF7c83387aDa48c10da44EC8E05F3
forge script --rpc-url http://127.0.0.1:8500/3 --sender 0x3011d1163eee4512e5e36a558b72220d86bd7fd6 --broadcast --unlocked contracts/script/01_DeploySourceAccount.s.sol 

# Deploy Paymaster 0x9381944580Ee7f90066E6b665A3D9eF1650CAd73
forge script --rpc-url http://127.0.0.1:8500/4 --sender 0x3e41c6473a51ad613796d5758d01f1c037adf94f --broadcast --unlocked contracts/script/02_DeployPaymaster.s.sol

# Deploy ReceiverAccountFactory 0x70b084e8d230a5f54575f25a8ee8d4038ca45e55
forge script --rpc-url http://127.0.0.1:8500/4 --sender 0x3e41c6473a51ad613796d5758d01f1c037adf94f --broadcast --unlocked contracts/script/03_DeployReceiverAccountFactory.s.sol

# Deploy NFT 0xDBfD5A731b744Aad08a4238387910B9ca7BddcB0
forge script --rpc-url http://127.0.0.1:8500/4 --sender 0x3e41c6473a51ad613796d5758d01f1c037adf94f --broadcast --unlocked contracts/script/04_DeployNFT.s.sol

# 