// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "../lib/helpers/SharedStruct.sol";

interface IMetaverseNFT {

    function initMetaverse(uint256 metaverseId, address creator, SharedStruct.ZoneInfo memory zone, SharedStruct.SpaceInfo[] memory spaceDatas) external;

    function mint(address mintTo, address creator, uint256 metaverseId, uint256 zoneIndex, uint256 currentTokenId, string memory uri, bytes memory data) external;

    function extendMetaverse(uint256 metaverseId, SharedStruct.ZoneInfo memory zone, SharedStruct.SpaceInfo[] memory spaceDatas) external;
}