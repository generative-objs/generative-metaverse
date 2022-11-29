// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "../lib/helpers/SharedStruct.sol";

interface IMetaverseSpaceNFT {
    event Mint(uint256 metaverseId, uint256 zoneIndex, uint256 currentTokenId, string uri, bytes data);
    event InitMetaverse(uint256 metaverseId, address creator, SharedStruct.ZoneInfo zone, SharedStruct.SpaceInfo[] spaceDatas);

    function initMetaverse(uint256 metaverseId, address creator, SharedStruct.ZoneInfo memory zone, SharedStruct.SpaceInfo[] memory spaceDatas) external;

    function extendMetaverse(uint256 metaverseId, SharedStruct.ZoneInfo memory zone, SharedStruct.SpaceInfo[] memory spaceDatas) external;
}