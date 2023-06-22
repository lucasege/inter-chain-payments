//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SimpleNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public tokenIds;
    event MintingNFT(address indexed recipient, uint256 value);

    constructor() ERC721("SimpleNFT", "SFT") {}

    function mintNFT(address recipient, string memory tokenURI) public payable returns (uint256) {
        emit MintingNFT(recipient, msg.value);
        require(msg.value >= 0.1 ether, "Must be at least 0.1 ether");
        tokenIds.increment();

        uint256 newItemId = tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}


// Simulate Validation:
// ({"sender":"0xb07C0EDf52dcc3075FF581016826B56c03c7A8d5","nonce":{"type":"BigNumber","hex":"0x00"},"initCode":"0x","callData":"0xb61d27f600000000000000000000000086f9dffe332ba023992e10d7ccffaab60ce08642000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000064eacabe14000000000000000000000000b07c0edf52dcc3075ff581016826b56c03c7a8d50000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","callGasLimit":{"type":"BigNumber","hex":"0x88b8"},"verificationGasLimit":{"type":"BigNumber","hex":"0x011170"},"preVerificationGas":{"type":"BigNumber","hex":"0x5208"},"maxFeePerGas":{"type":"BigNumber","hex":"0x00"},"maxPriorityFeePerGas":{"type":"BigNumber","hex":"0x00"},"paymasterAndData":"0x","signature":"0xe97dc89c7932e27f7dba569184cf3f1ba97956de873f369a69aa44df5729a3992e344aad2c0043b933640d7fc0782564fad92d20fba892256f83543b5ea3d0b11c"})